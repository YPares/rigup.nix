# Plan: VSCode + GitHub Copilot Integration Riglet

## Summary

Add a `vscode-copilot` riglet that sets up a project for use with **VSCode + GitHub Copilot**. Setup-only (no launch wrapper), copies workspace files that Copilot auto-discovers.

**Integration Pattern**: Same as `cursor.nix` with `justSetupProject = true`.

## VSCode + Copilot Configuration Mechanisms

### 1. Custom Instructions (Rig Manifest)

**File**: `.github/copilot-instructions.md` — auto-discovered by Copilot, no configuration needed.

- Must be at that exact workspace-relative path
- Only supports relative paths (no Nix store absolute paths)
- Must be copied into workspace (not symlinked)

**Refs**: [Custom Instructions](https://code.visualstudio.com/docs/copilot/customization/custom-instructions), [GitHub docs](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot), [No absolute paths](https://github.com/orgs/community/discussions/150959)

### 2. Prompt Commands (Slash Commands)

**Frontmatter Fields**:

- `description` - Brief description shown in command palette
- `name` - Name used after typing `/` in chat (defaults to filename)
- `argument-hint` - Hint text for chat input guidance
- `agent` - Agent type: `ask`, `agent`, `plan`, or custom agent name
- `model` - Language model selection
- `tools` - List of available tools (built-in, MCP, or extensions)

**Directory**: `.github/prompts/*.prompt.md` — auto-discovered when typing `/` in Copilot chat.

**Ref**: [Prompt Files](https://code.visualstudio.com/docs/copilot/customization/prompt-files)

### 3. MCP Servers

**File**: `.vscode/mcp.json` — auto-discovered by VSCode (not Copilot-specific).

Top-level key is **`servers`** (NOT `mcpServers` — that's Cursor's format). Optional `inputs` array for sensitive data placeholders.

**Refs**: [MCP guide](https://code.visualstudio.com/api/extension-guides/ai/mcp), [MCP GA](https://github.blog/changelog/2025-07-14-model-context-protocol-mcp-support-in-vs-code-is-generally-available/)

### 4. Permissions (Terminal Tool Auto-Approve)

**File**: `.vscode/settings.json`

Copilot agent mode asks for user confirmation before running terminal commands. This is controlled per-command via `chat.tools.terminal.autoApprove` — an object where keys are command names (or `/regex/` patterns), values are booleans.

**Relevant settings**:

| Setting                                       | Type   | Default                                | Description                                                              |
| --------------------------------------------- | ------ | -------------------------------------- | ------------------------------------------------------------------------ |
| `chat.tools.terminal.enableAutoApprove`       | bool   | `true`                                 | Master switch for terminal auto-approve                                  |
| `chat.tools.terminal.autoApprove`             | object | `{ "rm": false, "rmdir": false, ... }` | Per-command rules. `true` = auto-approve, `false` = require confirmation |
| `chat.tools.terminal.blockDetectedFileWrites` | string | `"outsideWorkspace"`                   | Block terminal file writes outside workspace                             |
| `chat.tools.global.autoApprove`               | bool   | `false`                                | Auto-approve ALL tools (YOLO mode — security risk)                       |

**Mapping from rig schema**:

- `rig.allExeNames` → auto-approve entries (`"toolname": true`)
- `rig.denyRules` → deny entries (`"/^toolname\\s+subcommand/": false`)

**Complication**: `.vscode/settings.json` may already exist with user settings. We cannot blindly overwrite it. Options:

1. **Merge** into existing settings.json (using `jq` or similar) — robust but adds a dependency
1. **Generate a separate file** and instruct users to merge manually — safe but tedious
1. **Use workspace-level settings only for permissions keys** — overwrite just the keys we care about via `jq`

**Decision**: Use `jq` to merge permissions keys into existing `.vscode/settings.json` (creating it if absent). Only touch `chat.tools.terminal.autoApprove`; never modify other keys.

**No `Read()` equivalent**: Cursor and Claude Code support explicit `Read(path/**)` rules to grant read access to Nix store paths. VSCode Copilot has no such mechanism — its `read_file` tool is **workspace-scoped** ([open feature request](https://github.com/microsoft/vscode/issues/289416)). Furthermore, **symlinks don't work**: VSCode resolves symlinks to their real path and then blocks access if the target is outside the workspace ([#289094](https://github.com/microsoft/vscode/issues/289094), [#292297](https://github.com/microsoft/vscode/issues/292297)). Therefore, the setup script must **copy `rig.docRoot` into the workspace** so that Copilot can read docs via its native file tools.

**Refs**: [Copilot Settings Reference](https://code.visualstudio.com/docs/copilot/reference/copilot-settings), [Agent Mode](https://code.visualstudio.com/docs/copilot/chat/chat-agent-mode)

## Implementation

### Nix Module

```nix
# riglets/vscode-copilot.nix
self:
{ pkgs, riglib, ... }:
let
  inherit (pkgs) lib;
in
{
  config.entrypoint =
    rig:
    let
      # Generate .vscode/mcp.json
      # IMPORTANT: VSCode uses "servers" as top-level key (NOT "mcpServers")
      mcpConfigJson = riglib.toJSON {
        servers = lib.mapAttrs (
          name: def:
          if def ? command then
            {
              type = "stdio";
              command = lib.getExe def.command;
            }
          else
            {
              type = if def.useSSE then "sse" else "http";
              inherit (def) url;
            }
            // lib.optionalAttrs (def.headers != { }) { inherit (def) headers; }
        ) rig.mcpServers;
      };

      # Generate terminal auto-approve rules from rig tools and deny rules
      autoApproveRules = riglib.toJSON (
        # Auto-approve all rig tools
        lib.genAttrs rig.allExeNames (_: true)
        # Deny specific subcommands via regex patterns
        // lib.mapAttrs' (
          tool: patterns:
          lib.nameValuePair
            "/^${tool}\\\\s+(${lib.concatStringsSep "|" patterns})/"
            false
        ) rig.denyRules
      );

      # Docs are copied into workspace at .github/rig-docs/
      # because Copilot's read_file tool is workspace-scoped and
      # symlinks to /nix/store/ are resolved and then blocked
      docsRelPath = ".github/rig-docs";

      # Generate manifest with workspace-relative doc paths
      manifestFile = pkgs.writeText "copilot-instructions.md" (
        builtins.readFile (
          rig.manifest.override {
            manifestFileName = "copilot-instructions.md";
            shownDocRoot = docsRelPath;
            shownActivationScript = ".github/rig-activate.sh";
          }
        )
      );
    in
    pkgs.writeShellScriptBin "vscode-copilot-setup" ''
      set -euo pipefail

      info() {
        printf "> \033[0;36m%s\033[0m\n" "$1" >&2
      }

      warn() {
        printf "> \033[0;33m%s\033[0m\n" "$1" >&2
      }

      err() {
        printf "> \033[0;31m%s\033[0m\n" "$1" >&2
      }

      is-ignored () {
        ${lib.getExe pkgs.git} check-ignore "$1" > /dev/null
      }

      cp-if-ignored() {
        local flags="$1" src="$2" dest="$3"
        if is-ignored "$dest"; then
          [[ -d "$dest" ]] && rm -rf "$dest"
          cp $flags "$src" "$dest"
          chmod -R +w "$dest"
          info "Overwrote $dest"
        else
          err "$dest is not gitignored. Will not write it"
          exit 1
        fi
      }

      # Ensure directories exist
      if [ ! -d ".vscode" ]; then
        err ".vscode/ folder does not exist. Create it first"
        exit 1
      fi

      if [ ! -d ".github" ]; then
        err ".github/ folder does not exist. Create it first"
        exit 1
      fi

      # 1. Copy activation script (provides PATH to rig tools)
      cp-if-ignored "" "${pkgs.writeText "rig-activate.sh" ''
        export PATH="${rig.toolRoot}/bin:$PATH"
      ''}" ".github/rig-activate.sh"

      # 2. Copy docRoot into workspace so Copilot's read_file can access it
      #    (symlinks don't work: VSCode resolves them and blocks access outside workspace)
      cp-if-ignored "-rL" "${rig.docRoot}" "${docsRelPath}"

      # 3. Copy rig manifest as Copilot instructions
      cp-if-ignored "" "${manifestFile}" .github/copilot-instructions.md

      # 4. Copy MCP config
      cp-if-ignored "" "${mcpConfigJson}" .vscode/mcp.json

      # 5. Merge terminal auto-approve rules into .vscode/settings.json
      if [ -f .vscode/settings.json ]; then
        ${lib.getExe pkgs.jq} -s \
          '.[0] * { "chat.tools.terminal.autoApprove": (.[0]["chat.tools.terminal.autoApprove"] // {} | . * .[1]) }' \
          .vscode/settings.json "${autoApproveRules}" > .vscode/settings.json.tmp
        mv .vscode/settings.json.tmp .vscode/settings.json
        info "Merged auto-approve rules into .vscode/settings.json"
      else
        ${lib.getExe pkgs.jq} -n \
          '{ "chat.tools.terminal.autoApprove": input }' \
          "${autoApproveRules}" > .vscode/settings.json
        info "Created .vscode/settings.json with auto-approve rules"
      fi

      # 6. Generate prompt command files (only if there are any)
      ${lib.optionalString (rig.promptCommands != { }) ''
        mkdir -p .github/prompts
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (cmdName: cmd: ''
            ${lib.optionalString cmd.useSubAgent ''
              warn "prompt command '${cmdName}': useSubAgent not supported by VSCode (ignoring)"
            ''}
            cmdPath=".github/prompts/${cmdName}.prompt.md"
            cp-if-ignored "" "${pkgs.writeText "prompt-${cmdName}.md" ''
---
description: ${cmd.description}
---

${cmd.template}
            ''}" "$cmdPath"
          '') rig.promptCommands
        )}
      ''}

      info "VSCode project setup complete"
      info "Open VSCode with: code ."
    '';

  config.riglets.vscode-copilot = {
    meta = {
      description = "Set up project for use with VSCode + GitHub Copilot";
      intent = "base";
      disclosure = "none";
      status = "stable";
      version = "0.1.0";
    };
  };
}
```

### Usage

1. Add to `rigup.toml`:

   ```toml
   [rigs.default.riglets]
   rigup = ["vscode-copilot", ...]
   ```

1. Prepare workspace:

   ```bash
   mkdir -p .vscode .github
   echo ".vscode/mcp.json" >> .gitignore
   echo ".github/copilot-instructions.md" >> .gitignore
   echo ".github/rig-activate.sh" >> .gitignore
   echo ".github/rig-docs" >> .gitignore
   echo ".github/prompts/" >> .gitignore
   ```

1. Run setup and open:

   ```bash
   rigup run ".#default"
   code .
   ```

## Feature Support Matrix

| Feature             | Claude Code      | Cursor             | copilot-cli | **vscode-copilot**       |
| ------------------- | ---------------- | ------------------ | ----------- | ------------------------ |
| **Rig Manifest**    | ✅ CLI flag      | ✅ File copy       | ✅ Env var  | ✅ File copy             |
| **MCP Servers**     | ✅ CLI flag      | ✅ File copy       | ❌ None     | ✅ File copy             |
| **Prompt Commands** | ✅ Plugin dir    | ✅ File copy       | ❌ None     | ✅ File copy             |
| **Permissions**     | ✅ settings.json | ✅ cli-config.json | ⚠️ CLI args | ✅ settings.json (merge) |
| **Launch Wrapper**  | ✅ Yes           | ⚠️ Optional        | ✅ Yes      | ❌ Setup only            |
| **Safety Checks**   | N/A              | ✅ gitignore       | N/A         | ✅ gitignore             |

## Open Questions

### Multi-Extension Support

`.vscode/mcp.json` is universal, but `.github/copilot-instructions.md` and `.github/prompts/` are Copilot-specific.

**Current Decision**: Focus on Copilot; other extensions get separate riglets.

## Testing Checklist

1. **Setup**: script succeeds, all files created, permissions correct, gitignore checks work
1. **Manifest**: visible in Copilot References list, context used in responses
1. **Prompt Commands**: appear on `/`, execute correctly, `readDocsFirst` preamble present
1. **MCP Servers**: visible in MCP panel, invocable
1. **Permissions**: rig tools auto-approved in terminal, deny rules block subcommands
1. **Docs access**: agent can read docs via `.github/rig-docs/` copy using Copilot's read_file tool
1. **Settings.json merge**: existing user settings preserved, only `chat.tools.terminal.autoApprove` key affected
1. **Errors**: missing directories caught, non-gitignored files rejected

## Implementation Steps

1. Create `riglets/vscode-copilot.nix`
1. Test manually with a sample rig
1. Document in `references/harness-integration.md`

## Future (v0.2.0)

- `.instructions.md` files with `applyTo` patterns
- User-scoped configuration
- Copilot extension detection/warnings
- Automatic `.gitignore` setup
