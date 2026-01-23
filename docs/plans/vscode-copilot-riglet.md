# Plan: VSCode + GitHub Copilot Integration Riglet

## Summary

Add a `vscode-copilot` riglet that sets up a project for use with **VSCode + GitHub Copilot**. This riglet provides setup-only functionality (no launch wrapper) and configures workspace files that Copilot auto-discovers.

**Target Environment**: VSCode (any recent version with Copilot extension installed)

**Integration Pattern**: Setup-only (similar to `cursor.nix` with `justSetupProject = true`)

**Key Insight**: VSCode/Copilot has well-defined auto-discovery mechanisms for configuration files in standard locations. No custom paths or launch wrappers needed.

## Motivation

VSCode has 70%+ market share among developers and GitHub Copilot is the most popular AI coding assistant. However, rigup.nix currently lacks direct VSCode support. Adding `vscode-copilot` will:

1. **Maximize reach** - VSCode is far more common than specialized tools like Cursor
2. **Leverage existing patterns** - VSCode's auto-discovery is similar to Cursor's approach
3. **Provide baseline integration** - Other VSCode extensions (Continue, Cline) could be added later

## Research: VSCode + Copilot Configuration Mechanisms

### 1. Custom Instructions (Rig Manifest)

**File**: `.github/copilot-instructions.md`

**Purpose**: Project-wide context automatically included in every Copilot request

**Discovery**: Auto-discovered by Copilot, no configuration needed

**Requirements**:
- Must be at `.github/copilot-instructions.md` (exact path, workspace-relative)
- Written in Markdown
- Setting `github.copilot.chat.codeGeneration.useInstructionFiles` must be enabled (likely default)

**Verification**: Shows up in "References" list of Copilot responses when used

**Limitations**:
- Cannot use absolute paths to Nix store (only workspace-relative paths work)
- `chat.instructionsFilesLocations` setting exists but only supports relative paths, not Nix store paths
- Must copy file into workspace (cannot symlink from Nix store reliably)

**References**:
- [Use custom instructions in VS Code](https://code.visualstudio.com/docs/copilot/customization/custom-instructions)
- [Adding repository custom instructions](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)
- [VS Code does not support absolute file path in instructions](https://github.com/orgs/community/discussions/150959)

### 2. Prompt Commands (Slash Commands)

**Directory**: `.github/prompts/`

**Format**: `*.prompt.md` files with YAML frontmatter

**Discovery**: Auto-discovered by Copilot when typing `/` in chat

**Example**:
```markdown
---
description: Generate a React form component
tools: [code, terminal]
---

Create a React form component called $1 with the following fields:
- Name (text input)
- Email (email input)
- Submit button
```

**Template Syntax**:
- `$ARGUMENTS` - All arguments combined
- `$1`, `$2`, etc. - Positional arguments

**Frontmatter Fields**:
- `description` - Brief description shown in command palette
- `tools` - List of available tools (e.g., `[code, terminal]`)
- `applyTo` - Glob pattern for when to auto-apply instructions

**Scopes**:
- **Workspace**: `.github/prompts/*.prompt.md` (committed with project)
- **User**: VS Code profile folder (available across projects)

**Additional Configuration**:
- `chat.promptFilesLocations` setting can specify additional directories (relative paths only)

**References**:
- [Use prompt files in VS Code](https://code.visualstudio.com/docs/copilot/customization/prompt-files)
- [Custom Slash Commands Guide](https://asepalazhari.com/blog/custom-slash-commands-github-copilot-vscode)
- [Prompt Files Tutorial](https://dev.to/pwd9000/supercharge-vscode-github-copilot-using-instructions-and-prompt-files-2p5e)

### 3. MCP Servers

**File**: `.vscode/mcp.json`

**Purpose**: Configure Model Context Protocol servers for extended capabilities

**Discovery**: Auto-discovered by VSCode (platform-standard, not Copilot-specific)

**Format**: Standard JSON
```json
{
  "mcpServers": {
    "server-name": {
      "type": "stdio",
      "command": "/path/to/server"
    }
  }
}
```

**Support**: Native VSCode support as of v1.102 (GA in 2025)

**Scope**: Works with any MCP-capable AI extension in VSCode (Copilot, Continue, Cline, etc.)

**References**:
- [MCP developer guide](https://code.visualstudio.com/api/extension-guides/ai/mcp)
- [Full MCP Specification Support](https://code.visualstudio.com/blogs/2025/06/12/full-mcp-spec-support)
- [MCP support GA announcement](https://github.blog/changelog/2025-07-14-model-context-protocol-mcp-support-in-vs-code-is-generally-available/)

### 4. Workspace Settings

**File**: `.vscode/settings.json`

**Purpose**: Project-specific VSCode settings

**Potential Use Cases**:
- Enable/configure MCP support
- Configure Copilot behavior
- Set permissions (if supported)

**Note**: Less critical for initial implementation - most features work via auto-discovery

## Comparison with Existing Riglets

### Claude Code (`claude-code.nix`)

**Approach**: Launch wrapper with CLI flags

```nix
entrypoint = pkgs.writeShellScriptBin "claude" ''
  exec ${claude-code} \
    --append-system-prompt "$(cat ${manifestPath})" \
    --settings "${settingsJson}" \
    --mcp-config ${mcpConfig} \
    --plugin-dir ${pluginDir}
'';
```

**Features**:
- ✅ Manifest injection via CLI flag
- ✅ MCP config via CLI flag
- ✅ Prompt commands via plugin directory
- ✅ Permissions via settings JSON

**Key Difference**: Claude Code accepts everything via CLI flags, so no file copying needed

### Cursor (`cursor.nix`)

**Approach**: Setup script + optional launch

```nix
entrypoint = pkgs.writeShellScriptBin "cursor-setup" ''
  cp-if-ignored "${cliConfigJson}" "$CURSOR_CONFIG_DIR/cli-config.json"
  cp-if-ignored "${mcpConfigJson}" "$CURSOR_CONFIG_DIR/mcp.json"
  # Generate .cursor/commands/*.md files
  cp-if-ignored "${rig.manifest}" "$CURSOR_CONFIG_DIR/rules/rig-manifest.mdc"
'';
```

**Features**:
- ✅ Copies files into `.cursor/` directory
- ✅ Checks files are gitignored before overwriting
- ✅ Sets up MCP config
- ✅ Generates prompt commands
- ✅ Optional launch of `cursor-agent`

**Key Pattern**: File-based configuration with safety checks

**Most Similar**: VSCode-Copilot will follow this pattern closely

### Copilot CLI (`copilot-cli.nix`)

**Approach**: Launch wrapper with env vars

```nix
entrypoint = pkgs.writeShellScriptBin "copilot" ''
  export COPILOT_CUSTOM_INSTRUCTIONS_DIRS="${instructionsDir}"
  exec ${copilot-cli} ${copilotArgs} "$@"
'';
```

**Features**:
- ✅ Manifest injection via env var
- ✅ Tool permissions via CLI args
- ❌ No MCP support (warns if configured)
- ❌ No prompt commands (warns if configured)

**Key Difference**: Minimal feature set, relies on CLI capabilities

## Technical Approach

### Architecture Decision: Setup-Only Pattern

**Rationale**:
1. VSCode is typically already running when users want to work on a project
2. No dedicated CLI tool exists (like `cursor-agent` or `claude`)
3. Users naturally launch VSCode themselves via `code .` or IDE
4. Setup script can be run once, then VSCode auto-discovers config
5. Like for cursor, an `activate.sh` script is needed so that the agent running inside VSCode can source it

**Pattern**: Similar to `cursor.nix` with `justSetupProject = true`

### File Operations Strategy

**Copy vs Symlink**:
- **Decision**: Copy files into workspace
- **Rationale**:
  - VSCode doesn't support absolute paths in config
  - Symlink behavior from Nix store is undocumented
  - Cursor riglet uses copy approach successfully
  - Simpler and more reliable

**Safety Checks** (following cursor pattern):
- Verify `.vscode/` and `.github/` directories exist
- Check files are gitignored before overwriting
- Provide clear error messages if safety checks fail

### Prompt Command Translation

Map riglet `promptCommands` schema to VSCode prompt file format:

**Input** (riglet schema):
```nix
promptCommands.analyze = {
  template = "Analyze $1 for potential issues";
  description = "Perform code analysis";
  useSubAgent = false;
};
```

**Output** (`.github/prompts/analyze.prompt.md`):
```markdown
---
description: Perform code analysis
---

Analyze $1 for potential issues
```

**Limitations**:
- `useSubAgent` not supported by VSCode prompt files (no equivalent)
- Limited frontmatter compared to Claude Code
- Should warn if riglet uses unsupported features

### MCP Server Translation

Map riglet MCP schema to `.vscode/mcp.json`:

**Input** (riglet schema):
```nix
mcpServers.my-server = {
  command = pkgs.my-mcp-server;
  transport = "stdio";
};
```

**Output** (`.vscode/mcp.json`):
```json
{
  "mcpServers": {
    "my-server": {
      "type": "stdio",
      "command": "/nix/store/.../bin/my-mcp-server"
    }
  }
}
```

**Note**: VSCode MCP config is platform-standard, should work with any MCP-capable extension

## Implementation Details

### Nix Module Structure

```nix
# riglets/vscode-copilot.nix
self:
{ pkgs, system, config, riglib, lib, ... }:
{
  options.vscode-copilot = {
    # Future: options for customization if needed
  };

  config.entrypoint = rig:
    let
      # Generate .vscode/mcp.json
      mcpConfigJson = (pkgs.formats.json {}).generate "mcp.json" {
        mcpServers = lib.mapAttrs (name: s: {
          type = s.transport;
        } // lib.optionalAttrs (s.resolvedCommand != null) {
          command = s.resolvedCommand;
        }
        // lib.optionalAttrs (s.url != null) {
          inherit (s) url;
        }
        // lib.optionalAttrs (s.headers != {}) {
          inherit (s) headers;
        }) rig.mcpServers;
      };

      # Generate manifest override for .github location
      manifestFile = rig.manifest.override {
        manifestFileName = "copilot-instructions.md";
        shownDocRoot = "$RIG_DOCS";  # Or relative path?
      };
    in
    pkgs.writeShellScriptBin "vscode-copilot-setup" ''
      set -euo pipefail

      # Helper functions (from cursor.nix pattern)
      info() { printf "> \033[0;36m%s\033[0m\n" "$1" >&2; }
      warn() { printf "> \033[0;33m%s\033[0m\n" "$1" >&2; }
      err() { printf "> \033[0;31m%s\033[0m\n" "$1" >&2; }

      is-ignored() {
        ${lib.getExe pkgs.git} check-ignore "$1" > /dev/null 2>&1
      }

      cp-if-ignored() {
        src="$1"
        dest="$2"
        if is-ignored "$dest"; then
          mkdir -p "$(dirname "$dest")"
          cp "$src" "$dest"
          chmod +w "$dest"
          info "Wrote $dest"
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

      # Set up environment
      export PATH="${rig.toolRoot}/bin:$PATH"
      export RIG_DOCS="${rig.docRoot}"

      # 1. Copy rig manifest as Copilot instructions
      cp-if-ignored "${manifestFile}" .github/copilot-instructions.md

      # 2. Copy MCP config
      cp-if-ignored "${mcpConfigJson}" .vscode/mcp.json

      # 3. Generate prompt command files
      mkdir -p .github/prompts
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (cmdName: cmd: ''
          ${lib.optionalString cmd.useSubAgent ''
            warn "prompt command '${cmdName}': useSubAgent not supported by VSCode (ignoring)"
          ''}
          cmdPath=".github/prompts/${cmdName}.prompt.md"
          cp-if-ignored "${pkgs.writeText "prompt-${cmdName}.md" ''
---
description: ${cmd.description}
---

${cmd.template}
          ''}" "$cmdPath"
        '') rig.promptCommands
      )}

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

### Usage Workflow

1. **Add riglet to rig** in `rigup.toml`:
   ```toml
   [rigs.default.riglets]
   rigup = ["vscode-copilot", ...]
   ```

2. **Prepare workspace**:
   ```bash
   mkdir -p .vscode .github
   # Ensure these are gitignored
   echo ".vscode/mcp.json" >> .gitignore
   echo ".github/copilot-instructions.md" >> .gitignore
   echo ".github/prompts/" >> .gitignore
   ```

3. **Run setup**:
   ```bash
   rigup run ".#default"
   ```

4. **Open VSCode**:
   ```bash
   code .
   ```

5. **Verify**:
   - Copilot chat should reference `.github/copilot-instructions.md`
   - Type `/` in Copilot chat to see custom commands
   - MCP servers should be available (check MCP panel)

### Error Handling

**Missing directories**:
```bash
if [ ! -d ".vscode" ]; then
  err ".vscode/ folder does not exist. Create it first"
  exit 1
fi
```

**Files not gitignored**:
```bash
if ! is-ignored "$dest"; then
  err "$dest is not gitignored. Will not write it"
  exit 1
fi
```

**Unsupported features**:
```bash
${lib.optionalString cmd.useSubAgent ''
  warn "prompt command '${cmdName}': useSubAgent not supported by VSCode (ignoring)"
''}
```

## Feature Support Matrix

| Feature | Claude Code | Cursor | copilot-cli | **vscode-copilot** |
|---------|-------------|--------|-------------|-------------------|
| **Rig Manifest** | ✅ CLI flag | ✅ File copy | ✅ Env var | ✅ File copy |
| **MCP Servers** | ✅ CLI flag | ✅ File copy | ❌ None | ✅ File copy |
| **Prompt Commands** | ✅ Plugin dir | ✅ File copy | ❌ None | ✅ File copy |
| **Permissions** | ✅ settings.json | ✅ cli-config.json | ⚠️ CLI args | ❓ TBD |
| **Launch Wrapper** | ✅ Yes | ⚠️ Optional | ✅ Yes | ❌ Setup only |
| **Config Method** | CLI flags | File copy | Env vars | File copy |
| **Safety Checks** | N/A | ✅ gitignore | N/A | ✅ gitignore |

## Open Questions

### 1. Manifest Doc Root Paths

**Question**: Should `shownDocRoot` in manifest be:
- `"$RIG_DOCS"` (absolute, via env var set in setup script)
- Relative path to workspace
- Something else?

**Context**: Copilot instructions are workspace-relative. If manifest references `$RIG_DOCS`, VSCode won't resolve it unless the env var is set.

**Recommendation**: Use relative paths or document that tools should be in PATH

### 2. Permissions Configuration

**Question**: Does VSCode/Copilot support tool execution permissions like Cursor/Claude Code?

**Research Needed**:
- Can we limit which tools Copilot can execute?
- Is there a `.vscode/settings.json` equivalent to Cursor's `cli-config.json`?
- Should we just rely on standard VSCode security?

**Current Decision**: Skip for v0.1.0, add later if needed

### 3. Multi-Extension Support

**Question**: Should this riglet work with Continue, Cline, etc., or stay Copilot-specific?

**Analysis**:
- `.vscode/mcp.json` is universal ✅
- `.github/copilot-instructions.md` is Copilot-specific ❌
- `.github/prompts/*.prompt.md` is Copilot-specific ❌

**Options**:
- A) Stay focused on Copilot (current plan)
- B) Add detection/configuration for other extensions
- C) Create separate riglets for each extension

**Current Decision**: Option A - focus on Copilot, other extensions can get separate riglets

### 4. Settings.json Management

**Question**: Should we generate/manage `.vscode/settings.json`?

**Considerations**:
- Users likely have existing settings.json
- Merging JSON is more complex than copying files
- May not be needed for basic functionality

**Current Decision**: Skip for v0.1.0, re-evaluate if needed

### 5. User vs Workspace Scope

**Question**: Should we support user-scoped config (profile folder) in addition to workspace?

**Current Decision**: Workspace-only for v0.1.0 (matches other riglets' project-scoped approach)

## Testing Strategy

### Manual Testing Checklist

1. **Setup**:
   - [ ] Run setup script succeeds
   - [ ] All expected files created
   - [ ] Files have correct permissions
   - [ ] Gitignore checks work

2. **Manifest Loading**:
   - [ ] Open VSCode
   - [ ] Start Copilot chat
   - [ ] Verify manifest in References list
   - [ ] Test if context is actually used

3. **Prompt Commands**:
   - [ ] Type `/` in Copilot chat
   - [ ] Custom commands appear
   - [ ] Commands execute correctly
   - [ ] Arguments work ($1, $ARGUMENTS)

4. **MCP Servers**:
   - [ ] MCP panel shows configured servers
   - [ ] Servers can be invoked
   - [ ] Error handling works

5. **Error Cases**:
   - [ ] Missing directories caught
   - [ ] Non-gitignored files rejected
   - [ ] Clear error messages displayed

### Integration Testing

Test in a real project with:
- Multiple prompt commands
- At least one MCP server
- Verify end-to-end workflow

## Implementation Steps

1. **Create `riglets/vscode-copilot.nix`** with basic structure
2. **Implement manifest copying** with gitignore checks
3. **Implement MCP config generation**
4. **Implement prompt command generation**
5. **Add helper functions** (info/warn/err messages)
6. **Test manually** with a sample rig
7. **Document** in `references/harness-integration.md`
8. **Add to llm-agents flake** (if vscode-copilot needs to be packaged)

## Future Enhancements

### v0.2.0 Possibilities

- **Settings.json management** for permissions/configuration
- **Alternative instruction mechanisms** (`.instructions.md` files with `applyTo`)
- **User-scoped configuration** support
- **Detection and warnings** if Copilot extension not installed
- **Automatic gitignore setup** (create/update .gitignore automatically)

### Other VSCode Extensions

Once vscode-copilot is stable, consider adding:
- `vscode-continue` - for Continue extension
- `vscode-cline` - for Cline (though Cline may deserve its own standalone riglet)

## References

### Official Documentation
- [VSCode AI Extensibility](https://code.visualstudio.com/api/extension-guides/ai/ai-extensibility-overview)
- [Custom Instructions](https://code.visualstudio.com/docs/copilot/customization/custom-instructions)
- [Prompt Files](https://code.visualstudio.com/docs/copilot/customization/prompt-files)
- [MCP Developer Guide](https://code.visualstudio.com/api/extension-guides/ai/mcp)
- [Copilot Settings Reference](https://code.visualstudio.com/docs/copilot/reference/copilot-settings)

### GitHub Documentation
- [Adding repository custom instructions](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)
- [5 tips for writing better custom instructions](https://github.blog/ai-and-ml/github-copilot/5-tips-for-writing-better-custom-instructions-for-copilot/)

### Community Resources
- [Custom Slash Commands Guide](https://asepalazhari.com/blog/custom-slash-commands-github-copilot-vscode)
- [Prompt Files Tutorial](https://dev.to/pwd9000/supercharge-vscode-github-copilot-using-instructions-and-prompt-files-2p5e)
- [Continue MCP Setup](https://docs.continue.dev/customize/deep-dives/mcp)

### Related Issues
- [VS Code does not support absolute file path](https://github.com/orgs/community/discussions/150959)
- [MCP support GA announcement](https://github.blog/changelog/2025-07-14-model-context-protocol-mcp-support-in-vs-code-is-generally-available/)
