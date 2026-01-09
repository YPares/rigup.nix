# Secret Management Integration for rigup.nix

## Research Summary

### Current State
- **Problem**: API keys and tokens for MCP servers are currently stored in plain text in `rigup.toml` or riglet configs
- **Location**: `mcp-context7.nix` has a TODO comment acknowledging this limitation
- **Flow**: `rigup.toml` → Nix evaluation → MCP JSON config → entrypoint script
- **Current workaround**: `rigup.local.toml` (gitignored) but secrets still visible in evaluated Nix

### Tools Researched

#### agenix
- **Encryption**: Uses `age` tool with SSH key infrastructure
- **API**: NixOS module that decrypts `.age` files to `/run/agenix/<name>` during system activation
- **Pros**: Simple, leverages existing SSH keys, small codebase
- **Cons**: Designed for NixOS system activation, not dev environments
- **Sources**: [GitHub](https://github.com/ryantm/agenix), [NixOS Wiki](https://nixos.wiki/wiki/Agenix)

#### sops-nix
- **Encryption**: Uses Mozilla SOPS with multiple backends (age, GPG, cloud KMS)
- **API**: NixOS module that decrypts to `/run/secrets/` atomically during activation
- **Pros**: Battle-tested, supports cloud KMS, atomic replacement, rollback support
- **Cons**: More complex, also designed for NixOS activation
- **Sources**: [GitHub](https://github.com/Mic92/sops-nix), [Recent guide (2025)](https://michael.stapelberg.ch/posts/2025-08-24-secret-management-with-sops-nix/)

### Key Challenge
Both tools are designed for **NixOS system activation**, while rigup.nix needs secrets in **development environments** (shell, entrypoint) without system-level activation.

## Design Questions to Clarify

Need to understand user preferences before finalizing approach.

## Proposed Approaches

### Approach A: Lightweight age-based solution (Recommended)
Build a custom rigup-specific secret management system using `age` directly:

**Architecture:**
1. **Encryption**: New CLI command `rigup secrets edit <name>` that encrypts with age
2. **Storage**: `.rigup/secrets/<name>.age` files (committed to git)
3. **Keys**: Use SSH keys (like agenix) or dedicated age keys
4. **Decryption**: At rig activation time (shell/entrypoint startup)
5. **Access**: Secrets exposed via environment variables or temporary files

**Integration points:**
- New riglet option: `secrets.<name> = { file = "./secrets/api-key.age"; }`
- Decryption script injected into shell activation or entrypoint
- MCP server configs reference env vars: `headers.CONTEXT7_API_KEY = "$CONTEXT7_API_KEY"`

**Advantages:**
- Tailored to rigup.nix use case
- No NixOS dependency
- Simpler than adapting existing tools
- Secrets properly encrypted in version control

**Implementation scope:**
- Add `age` package to rigup toolset
- Extend riglet schema with `secrets` option
- Add decryption logic to shell/entrypoint builders
- Create `rigup secrets` CLI commands
- Update MCP config generation to handle secret references

### Approach B: Integrate sops-nix with custom activation
Adapt sops-nix for non-NixOS use:

**Architecture:**
1. Use sops for encryption (supports cloud KMS, team workflows)
2. Create custom "activation" script that mimics NixOS module behavior
3. Inject into shell/entrypoint startup

**Advantages:**
- Leverage battle-tested tool
- Cloud KMS support for teams
- Atomic updates, rollback support

**Disadvantages:**
- More complex integration
- Heavier dependency
- May be overkill for dev environments

### Approach C: Use agenix with custom activation
Similar to B but with agenix's simpler model.

**Advantages:**
- Simpler than sops-nix
- Proven encryption patterns

**Disadvantages:**
- Still adapting system-level tool to dev use
- Less feature-rich than sops

### Approach D: Runtime-only decryption (no Nix integration)
Don't integrate into Nix evaluation at all:

**Architecture:**
1. Store encrypted secrets in repo (using age/sops manually)
2. User decrypts manually before running rig
3. Secrets loaded from environment or temporary files

**Advantages:**
- Minimal changes to rigup
- Clear separation of concerns

**Disadvantages:**
- Manual steps required
- Less integrated experience
- Secrets might persist in shell environment

## Recommendation: Approach A

**Rationale:**
- **Right-sized**: Addresses rigup's specific needs without over-engineering
- **Clean integration**: Natural extension of riglet schema
- **Developer-friendly**: Works in dev shells, not just system activation
- **Flexible**: Can support both SSH keys and dedicated age keys
- **Maintainable**: Smaller surface area than adapting sops-nix

**Trade-offs accepted:**
- No cloud KMS support initially (can add later)
- Custom implementation vs reusing existing tools
- Need to build CLI tooling

## User Decisions (Answered)

✅ **Approach**: Custom age-based solution (Approach A)
✅ **Use case**: Individual developer workflows
✅ **Exposure method**: Minijinja template rendering (not env vars)
✅ **Render timing**: Runtime rendering (secrets never in Nix store)
✅ **Storage**: Single `rigup.secrets.toml.age` file
✅ **Keys**: SSH keys only (no dedicated age keys)
✅ **Backwards compat**: Not needed (experimental features)

---

## Detailed Implementation Plan (Final - Minijinja Approach)

### Architecture Summary

**Core Principle**: Runtime-only decryption + template rendering. Secrets never enter Nix store.

**Flow**:
1. **Build time**: Riglets generate config *templates* with minijinja syntax
2. **Runtime** (shell/entrypoint activation):
   - Decrypt `rigup.secrets.toml.age`
   - Parse TOML into nested data structure
   - Render all config templates with minijinja
   - Place rendered configs in `/tmp/rigup-<rig>-<pid>/config/`
   - Set `XDG_CONFIG_HOME` to rendered config directory
   - Tools see fully-rendered configs

**Key management**: SSH ED25519 keys only (typically `~/.ssh/id_ed25519`)

**Secrets file format** (nested TOML):
```toml
# rigup.secrets.toml (decrypted view)
[mcp]
context7_api_key = "sk-..."
another_api_key = "..."

[database]
postgres_user = "admin"
postgres_password = "secret123"
```

**Config template example**:
```json
// mcp-config.json.tmpl
{
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp",
      "headers": {
        "CONTEXT7_API_KEY": "{{secrets.mcp.context7_api_key}}"
      }
    }
  }
}
```

### Implementation Phases

#### Phase 1: Define Secret Type System
**File**: `lib/secretTypes.nix` (NEW)

Create custom type for secrets:

```nix
{ lib }:
let
  inherit (lib) mkOptionType isAttrs;
in
{
  # Value constructor for secrets
  mkSecret = path: {
    _type = "secret";
    inherit path;  # Path in secrets TOML like "mcp.context7_api_key"
  };

  # Type checker
  isSecret = x: isAttrs x && x ? _type && x._type == "secret";

  # Option type for secrets
  types.secret = mkOptionType {
    name = "secret";
    description = "reference to encrypted secret";
    descriptionClass = "noun";
    check = isSecret;
    merge = lib.mergeEqualOption;
  };
}
```

Import in `lib/rigletSchema.nix` and expose via `riglib`.

**Usage in riglets**:
```nix
# mcp-context7.nix
{ config, lib, riglib, ... }:
{
  options.mcp-context7.apiKey = lib.mkOption {
    type = riglib.secretTypes.secret;  # Custom secret type
    description = "Context7 API key";
  };

  config.mcp-context7.apiKey = riglib.mkSecret "mcp.context7_api_key";

  config.riglets.mcp-context7.mcpServers.context7 = {
    transport = "http";
    url = "https://mcp.context7.com/mcp";
    headers.CONTEXT7_API_KEY = config.mcp-context7.apiKey;  # Secret reference
  };
}
```

**Advantage**: Type-safe, symmetric with regular config, no manual template syntax.

#### Phase 2: Secret-Aware Config Serializer
**File**: `lib/mkRiglib.nix:60` (add before `writeFileTree`)

Add serializer that converts secret values to minijinja templates:

```nix
# Recursively traverse config and convert secret references to template strings
secretsToTemplates = value:
  if isSecret value then "{{secrets.${replaceStrings ["."] ["."] value.path}}}"
  else if isAttrs value then mapAttrs (_: secretsToTemplates) value
  else if isList value then map secretsToTemplates value
  else value;

# Generate JSON config with secret templates
# Usage: mkConfigWithSecrets "myconfig" { apiKey = mkSecret "mcp.key"; }
mkConfigWithSecrets = name: data:
  let
    # Transform secrets to template strings
    templated = secretsToTemplates data;
    # Generate JSON (secrets are now strings like "{{secrets.mcp.key}}")
    jsonText = builtins.toJSON templated;
  in
  pkgs.writeText name jsonText;
```

Export in riglib attrset.

#### Phase 3: Auto-Detect Secret Usage
**File**: `lib/buildRig.nix:84`

Add helper to scan for secrets in config tree:

```nix
# Recursively check if config contains any secret values
containsSecrets = value:
  if riglib.isSecret value then true
  else if isAttrs value then any containsSecrets (attrValues value)
  else if isList value then any containsSecrets value
  else false;

# Check if any riglet uses secrets
usesSecrets = any (riglet: containsSecrets riglet) (attrValues evaluated.config.riglets);

# configRoot is built same as before, but will contain templates
configRoot = pkgs.symlinkJoin {
  name = "${rigName}-config";
  paths = map (riglet: riglet.configFiles) (attrValues evaluated.config.riglets);
};
```

Export `usesSecrets` in `baseRig` at line 370.

#### Phase 4: Runtime Config Renderer
**File**: `lib/mkRiglib.nix:151`

Add new utility function that renders config templates with secrets:

```nix
mkSecretConfigRenderer = {
  configRoot,  # Template directory to render
  rigName,
  agePackage ? pkgs.rage,
  projectRoot ? null,
}:
  pkgs.writeShellScript "render-secret-configs.sh" ''
    set -euo pipefail

    RIG_PROJECT_ROOT="''${RIG_PROJECT_ROOT:-${projectRoot or "$(pwd)"}}"
    SECRETS_FILE="$RIG_PROJECT_ROOT/rigup.secrets.toml.age"
    AGE_IDENTITY="''${AGE_IDENTITY:-$HOME/.ssh/id_ed25519}"

    # Create temp directory for rendered configs
    RENDERED_CONFIG_DIR="/tmp/rigup-${rigName}-$$"
    mkdir -p "$RENDERED_CONFIG_DIR"
    export XDG_CONFIG_HOME="$RENDERED_CONFIG_DIR"

    # Check SSH key exists
    if [[ ! -f "$AGE_IDENTITY" ]]; then
      echo "❌ SSH key not found: $AGE_IDENTITY" >&2
      echo "   Set AGE_IDENTITY env var" >&2
      exit 1
    fi

    # Check secrets file exists
    if [[ ! -f "$SECRETS_FILE" ]]; then
      echo "❌ Secrets file not found: $SECRETS_FILE" >&2
      echo "   Run: rigup secrets edit" >&2
      exit 1
    fi

    # Decrypt secrets TOML
    DECRYPTED_SECRETS=$(${getExe agePackage} -d -i "$AGE_IDENTITY" "$SECRETS_FILE" 2>/dev/null) || {
      echo "❌ Failed to decrypt secrets" >&2
      exit 1
    }

    # Save decrypted TOML to temp file for minijinja
    SECRETS_TOML_FILE=$(mktemp)
    echo "$DECRYPTED_SECRETS" > "$SECRETS_TOML_FILE"
    trap "rm -f $SECRETS_TOML_FILE" EXIT

    # Render each config template
    ${pkgs.lib.getExe pkgs.findutils} ${configRoot} -type f | while read -r template; do
      rel_path="''${template#${configRoot}/}"
      output="$RENDERED_CONFIG_DIR/$rel_path"
      mkdir -p "$(dirname "$output")"

      # Render template with minijinja, passing secrets TOML directly
      ${getExe pkgs.minijinja} --strict "$template" "$SECRETS_TOML_FILE" \
        --format toml --output "$output" 2>/dev/null || {
        # If rendering fails (no templates), just copy file as-is
        cp "$template" "$output"
      }
    done

    echo "✅ Rendered configs to $RENDERED_CONFIG_DIR" >&2
    echo "export XDG_CONFIG_HOME=$RENDERED_CONFIG_DIR"  # For eval in caller
  '';
```

Export in riglib attrset.

**Note**: Passes decrypted TOML directly to minijinja (`--format toml`) - no conversion needed!

#### Phase 5: Update Shell Output
**File**: `lib/buildRig.nix:193`

Modify shell to render configs at startup:

```nix
shell = let
  configRenderer = if usesSecrets
    then riglib.mkSecretConfigRenderer {
      inherit configRoot rigName;
      agePackage = pkgs.rage;
    }
    else null;
in pkgs.mkShell {
  packages = [ toolRoot ]
    ++ optional (configRenderer != null) pkgs.rage
    ++ optional (configRenderer != null) pkgs.minijinja;

  shellHook = ''
    ${optionalString (configRenderer != null) ''
      # Render configs with secrets
      eval "$(${configRenderer})"
    ''}
    ${optionalString (configRenderer == null) ''
      # No secrets - use static config
      export XDG_CONFIG_HOME="${configRoot}"
    ''}

    # ... rest of banner
    ${optionalString (configRenderer != null) ''
      printf "  ${green}Configs rendered${reset} with secrets in $XDG_CONFIG_HOME\n"
    ''}
  '';
};
```

#### Phase 6: Update Home Output
**File**: `lib/buildRig.nix:171`

Add config rendering to `activate.sh`:

```nix
home = let
  configRenderer = if usesSecrets
    then riglib.mkSecretConfigRenderer { inherit configRoot rigName; }
    else null;
in pkgs.runCommand "${rigName}-home" {} ''
  mkdir -p $out
  ln -s ${toolRoot} $out/.local
  ln -s ${docRoot} $out/docs
  ${optionalString (configRenderer != null) "ln -s ${configRenderer} $out/render-configs.sh"}

  cat > $out/activate.sh <<'EOF'
export PATH="$out/.local/bin:$PATH"
${if configRenderer != null then ''
  eval "$($out/render-configs.sh)"
'' else ''
  export XDG_CONFIG_HOME="${configRoot}"
''}
EOF

  ln -s ${manifest.override { shownDocRoot = "./docs"; }} $out/RIG.md
'';
```

#### Phase 7: Update Entrypoints
**Files**: `riglets/claude-code.nix:22`, `riglets/cursor-agent.nix:30`

Render configs before starting entrypoint:

```nix
config.entrypoint = rig: let
  configRenderer = if rig.usesSecrets
    then riglib.mkSecretConfigRenderer {
      configRoot = rig.configRoot;
      rigName = rig.name;
    }
    else null;
in pkgs.writeShellScriptBin "claude" ''
  set -euo pipefail

  ${if configRenderer != null then ''
    # Render configs with secrets
    eval "$(${configRenderer})"
  '' else ''
    export XDG_CONFIG_HOME="${rig.configRoot}"
  ''}

  export PATH="${rig.toolRoot}/bin:$PATH"
  export RIG_MANIFEST="${manifestPath}"

  exec ${getExe claude-code} \
    --mcp-config "$XDG_CONFIG_HOME/mcp-config.json" \
    "$@"
'';
```

**Note**: MCP config path now references rendered location, not static path.

#### Phase 8: CLI Commands
**File**: `packages/rigup/src/main.rs`

Add to `Commands` enum:

```rust
Secrets {
    #[command(subcommand)]
    command: SecretsCommands,
}

#[derive(Subcommand)]
enum SecretsCommands {
    Edit {
        #[arg(short = 'R', long)]
        recipients: Vec<String>,
    },
}
```

**File**: `packages/rigup/src/commands/secrets.rs` (NEW)

Implement one command:

**`rigup secrets edit [-R recipient...]`**:
- Default recipient: SSH public key from `~/.ssh/id_ed25519.pub`
- If `rigup.secrets.toml.age` exists: decrypt with SSH key
- If not: create new TOML with example structure:
  ```toml
  # Example: MCP server API keys
  [mcp]
  context7_api_key = "sk-..."

  # Example: Database credentials
  [database]
  postgres_user = "admin"
  postgres_password = "secret"
  ```
- Open in `$EDITOR` (default: `vim`)
- Save and re-encrypt with `rage` for all recipients

Implementation sketch:
```rust
pub fn secrets_edit(recipients: Vec<String>) -> Result<()> {
    let secrets_file = Path::new("rigup.secrets.toml.age");
    let identity_path = format!("{}/.ssh/id_ed25519", env::var("HOME")?);

    // Decrypt or create template
    let content = if secrets_file.exists() {
        decrypt_with_age(secrets_file, &identity_path)?
    } else {
        include_str!("../../templates/secrets.toml.template")
    };

    // Edit in $EDITOR
    let edited = open_in_editor(&content)?;

    // Validate TOML syntax
    toml::from_str::<toml::Value>(&edited)?;

    // Determine recipients
    let recips = if recipients.is_empty() {
        vec![read_ssh_pubkey(&format!("{}.pub", identity_path))?]
    } else {
        recipients
    };

    // Encrypt with rage
    encrypt_with_age(&edited, secrets_file, &recips)?;

    Ok(())
}
```

**No `show` command needed** - secrets structure is freeform, riglets just reference paths.

#### Phase 9: Update MCP Riglets (Type-Based Approach)
**File**: `riglets/mcp-context7.nix`

Rewrite to use `types.secret` - much cleaner:

```nix
{ pkgs, lib, riglib, ... }:
{
  # Define option with secret type
  options.mcp-context7.apiKey = lib.mkOption {
    type = riglib.secretTypes.secret;
    description = "Context7 API key from encrypted secrets";
  };

  # Set the secret reference
  config.mcp-context7.apiKey = riglib.mkSecret "mcp.context7_api_key";

  # Use secret in config - serializer handles template conversion
  config.riglets.mcp-context7 = {
    configFiles = riglib.writeFileTree {
      "mcp/context7.json" = riglib.mkConfigWithSecrets "context7-config" {
        transport = "http";
        url = "https://mcp.context7.com/mcp";
        headers = {
          # This is a secret value - automatically becomes {{secrets.mcp.context7_api_key}}
          CONTEXT7_API_KEY = config.mcp-context7.apiKey;
        };
      };
    };

    meta = {
      description = "MCP Context7 Server";
      intent = "base";
      status = "experimental";
      version = "0.2.0";
    };
  };
}
```

**Key improvements**:
- No manual template syntax - just use the secret value directly
- Type-safe: can't accidentally use wrong type
- Auto-detected: `usesSecrets` flag no longer needed (scans for secret types)
- Symmetric: secrets handled same as any other config option

Apply similar pattern to other MCP riglets.

#### Phase 10: Templates & Docs
**File**: `templates/default/.gitignore`

Add:
```
# Never commit secrets!
rigup.secrets.toml
rigup.secrets.toml.age
```

**File**: `riglets/secret-management/` (NEW)

Create documentation riglet with SKILL.md covering:
- Single-file TOML secret workflow (edit → encrypt → activate)
- SSH key usage (no dedicated age keys needed)
- Team usage patterns (multiple recipients via `-R`)
- Troubleshooting decryption errors
- Example: setting up MCP server authentication

---

## Critical Files Summary

| File | Change Type | Purpose |
|------|-------------|---------|
| `lib/secretTypes.nix` | Create | Define `types.secret`, `mkSecret`, `isSecret` |
| `lib/rigletSchema.nix` | Modify | Import and expose secret types via riglib |
| `lib/mkRiglib.nix` | Modify | Add `mkConfigWithSecrets`, `secretsToTemplates`, `mkSecretConfigRenderer` |
| `lib/buildRig.nix` | Modify | Add `containsSecrets`, auto-detect `usesSecrets` |
| `riglets/claude-code.nix` | Modify | Add config rendering to entrypoint |
| `riglets/cursor-agent.nix` | Modify | Add config rendering to entrypoint |
| `riglets/mcp-context7.nix` | Rewrite | Use `types.secret` for API key |
| `packages/rigup/src/main.rs` | Modify | Add `secrets edit` subcommand |
| `packages/rigup/src/commands/secrets.rs` | Create | Implement `edit` command |
| `packages/rigup/src/commands/mod.rs` | Modify | Export secrets module |
| `packages/rigup/templates/secrets.toml.template` | Create | Template for new secrets file |
| `templates/default/.gitignore` | Modify | Ignore `rigup.secrets.toml*` |
| `riglets/secret-management/` | Create | Documentation riglet |

---

## User Workflow (Final - Type-Based + Minijinja)

### Initial Setup
```bash
# Edit secrets file (creates nested TOML if doesn't exist)
rigup secrets edit

# Opens editor with template:
# [mcp]
# context7_api_key = "sk-..."
#
# [database]
# postgres_user = "admin"
# postgres_password = "secret"

# Save and quit - automatically encrypted
```

### Using Secrets in Riglet Configs (Type-Safe Way)
Riglets use `types.secret` for type safety:
```nix
{ config, lib, riglib, ... }:
{
  # Define option with secret type
  options.myapp.apiKey = lib.mkOption {
    type = riglib.secretTypes.secret;
  };

  # Reference secret from TOML
  config.myapp.apiKey = riglib.mkSecret "mcp.context7_api_key";

  # Use in config - serializer automatically converts to minijinja template
  config.riglets.myapp.configFiles = riglib.writeFileTree {
    "myapp/config.json" = riglib.mkConfigWithSecrets "config" {
      api_key = config.myapp.apiKey;  # Becomes {{secrets.mcp.context7_api_key}}
      db = {
        user = riglib.mkSecret "database.postgres_user";
        password = riglib.mkSecret "database.postgres_password";
      };
    };
  };
}
```

**No manual template syntax needed!** The type system and serializer handle everything.

### Team Collaboration
```bash
# Add teammate's SSH pubkey as recipient
rigup secrets edit -R "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAbc..."

# Now both can decrypt and edit
```

### Using Rigs
```bash
# Shell mode - configs auto-rendered with secrets
rigup shell .#default
# Configs in $XDG_CONFIG_HOME contain decrypted values

# Entrypoint mode - configs rendered before Claude starts
rigup run .#default-claude  # ✅ MCP servers authenticated
```

---

## Verification Plan

After implementation, test:

1. **Secret file creation**: `rigup secrets edit` → add nested TOML → save → verify encrypted
2. **Template syntax**: Add `{{secrets.test.key}}` to a config → verify renders correctly
3. **Shell activation**: `rigup shell` → `cat $XDG_CONFIG_HOME/myapp/config.json` → verify secrets injected
4. **Entrypoint activation**: `rigup run .#default-claude` → verify MCP auth works
5. **Missing file error**: `rm rigup.secrets.toml.age` → `rigup shell` → clear error message
6. **Missing key error**: Rename SSH key → verify helpful error
7. **Invalid template**: Use `{{secrets.nonexistent}}` → verify minijinja fails gracefully
8. **Multi-recipient**: `rigup secrets edit -R <pubkey>` → verify both can decrypt
9. **No secrets**: Rig without `usesSecrets = true` → verify uses static config, no rendering

---

