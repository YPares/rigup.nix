# Plan: Add Prompt Command Support to rigup.nix

## Summary

Add support for riglets to define **prompt commands** with type-safe Nix metadata. Commands are collected into `rig.promptCommands` and `rig.promptCommandRoot`, then each harness's entrypoint translates metadata to harness-specific config.

**Terminology**: rigup calls these "prompt commands" (generic), known as "slash commands" in Claude Code.

**Architecture**: Nix schema for metadata, generic storage, harness-specific translation via entrypoints (similar to how rigup handles other harness integrations).

## What Are Prompt Commands?

Prompt commands are **reusable markdown prompt files with structured metadata**:
- **Content**: Markdown with prompt instructions (can reference $ARGUMENTS, $1, $2, etc.)
- **Metadata**: Defined in Nix (type-safe schema) - description, allowedTools, arguments, etc.
- **Storage**: Generic location in rig (`promptCommandRoot/`), not harness-specific paths
- **Exposure**: Each harness's entrypoint translates metadata to harness-specific config
- **No local file modification**: Commands exposed via harness config, not by modifying user's project files

## Harness Slash Command Support Research

rigup.nix currently supports 4 harnesses via entrypoint riglets. Here's what each supports for slash commands/prompt commands:

### 1. Claude Code ✅ Full Support

**Storage**: `.claude/commands/` (project) or `~/.claude/commands/` (global)

**Format**: Markdown files with optional YAML frontmatter

**Frontmatter fields** (all optional):
- `description` - Brief description shown in `/help`
- `allowed-tools` - Tool permissions (e.g., `Bash(jj:*)`)
- `argument-hint` - UI hint (e.g., `[pr-number] [priority]`)
- `model` - Override model for this command
- `context` - Set to `fork` for sub-agent execution
- `agent` - Agent type when using `fork`
- `hooks` - PreToolUse/PostToolUse handlers

**Template syntax**:
- `$ARGUMENTS` - All arguments combined
- `$1`, `$2`, `$3` - Positional arguments
- `!`command`` - Bash command execution in template

**Config method**: hardcoded to `.claude/commands/` and `~/.claude/commands/`
  OR loadable from plugins specified via --plugin-dir (preferred, as this requires no project files modifications)

**References**: [Claude Code slash commands](https://code.claude.com/docs/en/slash-commands), [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference)

### 2. Cursor Agent ✅ Beta Support

**Storage**: `.cursor/commands/` (project) or `~/.cursor/commands/` (global)

**Format**: Plain Markdown files (no frontmatter required)

**Features**:
- Commands auto-discovered by typing `/`
- Additional text after command name included in prompt
- No special metadata/frontmatter documented (feature in beta)
- Standard Markdown formatting (headings, lists, checkboxes)

**Limitations**:
- Feature in beta, "syntax may change"
- No documented frontmatter fields
- Simpler than Claude Code (just Markdown content)

**Config method**: None documented (file-based only)

**References**: [Cursor Commands docs](https://cursor.com/docs/context/commands), [Cursor changelog](https://cursor.com/changelog/1-6)

### 3. OpenCode ✅ Full Support

**Storage**: `.opencode/commands/` (project) or `~/.config/opencode/commands/` (global)

**Format**: Markdown files with optional YAML frontmatter

**Frontmatter fields** (all optional):
- `description` - Brief explanation shown in TUI
- `agent` - Specifies which agent executes command
- `model` - Override default model
- `subtask` - Force subagent invocation (boolean)

**Template syntax**:
- `$ARGUMENTS` - All arguments combined
- `$1`, `$2`, `$3` - Positional arguments
- `!`command`` - Shell output injection
- `@filename` - File content inclusion

**Config method**: Commands can be defined in `opencode.json` via `command` option:
```json
{
  "command": {
    "test": {
      "template": "Run tests...",
      "description": "Run tests",
      "model": "anthropic/claude-sonnet-4-5"
    }
  }
}
```

**References**: [OpenCode commands docs](https://opencode.ai/docs/commands/), [OpenCode config docs](https://opencode.ai/docs/config/)

### 4. GitHub Copilot CLI ❌ No Custom Command Support

**Status**: Only built-in slash commands (`/login`, `/model`, `/usage`, `/delegate`, `/feedback`)

**Custom commands**: Feature requested ([Issue #618](https://github.com/github/copilot-cli/issues/618)) but **not currently supported**

**Workaround**: No alternative for custom prompt commands

**References**: [Copilot CLI docs](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli), [GitHub repo](https://github.com/github/copilot-cli)

### Summary Table

| Harness | Support | Storage Location | Frontmatter | Special Syntax | Status |
|---------|---------|------------------|-------------|----------------|--------|
| Claude Code | ✅ Full | `.claude/commands/` | Rich (7+ fields) | `$ARGS`, `$1`, `!cmd` | Stable |
| Cursor Agent | ✅ Beta | `.cursor/commands/` | None documented | Basic | Beta |
| OpenCode | ✅ Full | `.opencode/commands/` | 4 fields | `$ARGS`, `$1`, `!cmd`, `@file` | Stable |
| Copilot CLI | ❌ None | N/A | N/A | N/A | Requested |

### Implementation Priority

1. **Phase 1**: Core infrastructure + Claude Code entrypoint
2. **Phase 2**: OpenCode entrypoint (similar frontmatter pattern)
3. **Phase 3**: Cursor Agent entrypoint (simpler, no frontmatter)
4. **Phase 4** (blocked): Copilot CLI (wait for upstream support)

## Design Overview

### 1. Schema Addition (`lib/rigletSchema.nix`)

Add `promptCommands` option under `options.riglets.<rigletname>` (alongside existing options like `tools`, `docs`, `configFiles`):

```nix
# Inside: options.riglets = mkOption { type = types.attrsOf (types.submodule { options = { ... }
promptCommands = mkOption {
  description = "Prompt commands this riglet provides (slash commands in harnesses like Claude Code)";
  type = types.attrsOf (types.submodule {
    options = {
      template = mkOption {
        description = "Markdown content of the template. Can reference variables like $ARGUMENTS, $1, $2, etc.";
        type = types.str;
      };

      description = mkOption {
        description = "Brief description of what this template does";
        type = types.str;
      };

      allowedTools = mkOption {
        description = "List of tools this command is allowed to use (as Nix packages/paths, like config.riglets.<name>.tools)";
        type = types.listOf packageLike;
        default = [];
      };

      arguments = mkOption {
        description = "Expected arguments with descriptions";
        type = types.listOf (types.submodule {
          options = {
            name = mkOption { type = types.str; };
            description = mkOption { type = types.str; default = ""; };
            required = mkOption { type = types.bool; default = false; };
          };
        });
        default = [];
      };

      model = mkOption {
        description = "Preferred model for this template (harness-specific, may be ignored)";
        type = types.nullOr types.str;
        default = null;
      };

      category = mkOption {
        description = "Category for grouping templates";
        type = types.nullOr types.str;
        default = null;
      };

      useSubAgent = mkOption {
        description = "Have a sub-agent read and run the command";
        type = types.bool;
        default = false;
      };
    };
  });
  default = {};
};
```

**Rationale**:
- Uses Nix submodule with typed fields (similar to other rigup integrations)
- Generic metadata (not tied to specific harness)
- Content is just markdown string (no file paths needed)
- Harness-agnostic options support multiple harnesses:
  - `allowedTools` → Nix packages/paths (entrypoints derive harness-specific permission syntax)
  - `model` → supported by Claude Code, OpenCode
  - `context: "fork"` → Claude Code's fork mode, OpenCode's `subtask: true`
  - `subtask` → Direct OpenCode support
  - `arguments` → Generate `argument-hint` for Claude Code

### 2. Collection Logic (`lib/buildRig.nix`)

Add collection logic (similar to how other rig capabilities are collected):

```nix
# Collect prompt commands with metadata
promptCommands =
  let
    collectFromRiglet = rigletName: riglet:
      mapAttrs (templateName: def:
        def // {
          inherit rigletName templateName;
          # Compute namespaced name
          namespacedName = "${rigletName}/${templateName}";
        }
      ) riglet.promptCommands;
  in
    foldl' (acc: r: acc // collectFromRiglet r.name r) {} (
      mapAttrsToList (n: r: r // { name = n; }) evaluated.config.riglets
    );

# Build derivation with template files
promptCommandRoot = riglib.writeFileTree (
  foldl' (acc: rigletName:
    let
      riglet = evaluated.config.riglets.${rigletName};
      templates = mapAttrs (name: def:
        pkgs.writeText "${name}.md" def.content
      ) riglet.promptCommands;
    in
      acc // { "${rigletName}" = templates; }
  ) {} (attrNames evaluated.config.riglets)
);
```

Add both `promptCommands` and `promptCommandRoot` to `baseRig` attrset (alongside existing attributes like `allExeNames`, `toolRoot`, etc.).

**Rationale**:
- `promptCommands` attrset contains structured metadata (for entrypoints to translate)
- `promptCommandRoot` derivation contains markdown files (for storage/reading)
- Namespaced by riglet (prevents conflicts)
- Same collection pattern as other rig capabilities

### 3. Integration into Rig Outputs

**home output** (in the `home` derivation):
```nix
ln -s ${baseRig.promptCommandRoot} $out/promptCommands
```

**shell output**: No changes (not harness-specific)

**entrypoint output**: Each entrypoint translates `rig.promptCommands` to harness config

**Rationale**:
- Generic `promptCommands/` folder (like `docs/`)
- Not `.claude/commands` (harness-specific)
- Entrypoints decide how to expose to harnesses

### 4. Entrypoint Examples

Each harness's entrypoint translates `rig.promptCommands` metadata to its specific format:

#### Claude Code Entrypoint

Update `riglets/claude-code.nix` to generate a plugin and load via `--plugin-dir`:

**Solution**: Build a Claude Code plugin with commands and load it via `--plugin-dir` flag:

```nix
# In entrypoint function:
pluginDir = pkgs.runCommandLocal "rig-plugin" {} ''
  mkdir -p $out/.claude-plugin $out/commands

  # Generate plugin manifest
  cat > $out/.claude-plugin/plugin.json <<'EOF'
  {
    "name": "rig",
    "description": "Prompt commands for ${rig.name}",
    "version": "1.0.0"
  }
  EOF

  # Generate command files
  ${lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: tmpl:
      let
        # Derive Claude Code permission syntax from tool packages
        allowedToolsStr = lib.concatMapStringsSep ", " (tool:
          let toolName = lib.baseNameOf (lib.getExe tool);
          in "Bash(${toolName}:*)"
        ) tmpl.allowedTools;

        # Generate frontmatter from metadata
        frontmatter = lib.optionalString (tmpl.description != "" || tmpl.allowedTools != [] || tmpl.model != null) ''
          ---
          ${lib.optionalString (tmpl.description != "") "description: ${tmpl.description}"}
          ${lib.optionalString (tmpl.allowedTools != []) "allowed-tools: ${allowedToolsStr}"}
          ${lib.optionalString (tmpl.model != null) "model: ${tmpl.model}"}
          ${lib.optionalString (tmpl.arguments != []) "argument-hint: [${lib.concatMapStringsSep "] [" (a: a.name) tmpl.arguments}]"}
          ${lib.optionalString (tmpl.context == "fork") "context: fork"}
          ---

        '';
        fullContent = frontmatter + tmpl.content;
      in ''
        cat > $out/commands/${name}.md <<'EOF'
        ${fullContent}
        EOF
      ''
    ) rig.promptCommands
  )}
'';

# In wrapper script:
exec ${pkgs.lib.getExe claude-code} \
  --append-system-prompt "$(cat ${manifestPath})" \
  --settings "${settingsJson}" \
  ${lib.optionalString (rig.promptCommands != {}) "--plugin-dir ${pluginDir}"} \
  "$@"
```

**Plugin contains**:
- `commands/*.md` - Prompt commands with metadata-derived frontmatter

**Usage**:
- Commands invoked as `/rig:command-name` (namespaced by plugin name)

**Benefits**:
- ✅ NO project file modification
- ✅ Commands in clean plugin structure
- ✅ Commands properly namespaced
- ✅ Follows Claude Code plugin conventions

**References**: [Claude Code Plugins](https://code.claude.com/docs/en/plugins)

#### OpenCode Entrypoint

Update `riglets/opencode.nix` to add commands to existing config JSON:

**Advantage**: OpenCode supports defining commands in config.json via `command` option - NO file modification needed!

```nix
# In opencodeConfigJson generation, add:
opencodeConfigJson = (pkgs.formats.json { }).generate "opencode-config.json" {
  "$schema" = "https://opencode.ai/config.json";

  # ... existing config ...

  # Add commands from rig.promptCommands
  command = lib.mapAttrs (name: tmpl: {
    template = tmpl.content;
    description = tmpl.description;
  }
  // lib.optionalAttrs (tmpl.model != null) { model = tmpl.model; }
  // lib.optionalAttrs (tmpl.subtask || tmpl.context == "fork") { subtask = true; }
  ) rig.promptCommands;
};
```

Then pass via `OPENCODE_CONFIG` as already done in the entrypoint.

**Benefits**:
- ✅ NO project file modification
- ✅ Commands defined in existing generated config
- ✅ Clean separation (config managed by Nix)

#### Cursor Agent Entrypoint (Future)

Simpler for `riglets/cursor-agent.nix` (no frontmatter):

```nix
cursorCommandsDir = pkgs.runCommandLocal "cursor-commands" {} ''
  mkdir -p $out
  ${lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: tmpl: ''
      mkdir -p $out/${lib.dirOf name}
      cat > $out/${name}.md <<'EOF'
      ${tmpl.content}
      EOF
    '') rig.promptCommands
  )}
'';
```

Copy to `$CURSOR_CONFIG_DIR/commands/` in wrapper script (similar to how it handles other config).

**Note**: Copilot CLI has no custom command support, so no entrypoint changes needed.

#### Summary: Config vs File Modification

| Harness | Method | File Modification | Status |
|---------|--------|-------------------|--------|
| **OpenCode** | Config JSON (`command` option) | ✅ None | Clean |
| **Claude Code** | Plugin via `--plugin-dir` | ✅ None | Clean |
| **Cursor Agent** | Copy to `$CURSOR_CONFIG_DIR/commands/` | ⚠️ User-specified dir | Acceptable |
| **Copilot CLI** | N/A | N/A | Not supported |

**Note**: All harnesses with support avoid modifying project files (OpenCode via config, Claude Code via plugins, Cursor via user-specified dir).

### 5. Example Riglet Usage

**Simple inline**:
```nix
config.riglets.jj-workflow = {
  promptCommands = {
    commit = {
      description = "Create JJ commit with conventions";
      content = ''
        Create a jujutsu commit with message: $1

        First check current status with `jj status`.
        Follow semantic commit conventions (feat/fix/docs/refactor).
      '';
      allowedTools = [pkgs.jujutsu];  # Nix package reference
      arguments = [{
        name = "message";
        description = "Commit message";
        required = true;
      }];
    };

    sync = {
      description = "Describe, commit, and push";
      content = ''
        Describe changes with message: $1
        Create new revision and push to remote.
      '';
      allowedTools = [pkgs.jujutsu];  # Nix package reference
      arguments = [{
        name = "message";
        description = "Commit message";
        required = false;
      }];
    };
  };
};
```

**With folder** (for longer templates):
```nix
config.riglets.jj-workflow = {
  promptCommands = {
    commit = {
      description = "Create JJ commit with conventions";
      content = builtins.readFile ./prompt-templates/commit.md;
      allowedTools = [pkgs.jujutsu];  # Nix package reference
      arguments = [{ name = "message"; required = true; }];
    };
  };
};
```

**Rationale**:
- Metadata is explicit and type-safe
- Content can be inline or read from files
- No YAML frontmatter in source
- Harness-agnostic definitions

### 6. Manifest Documentation (`lib/genManifest.nix`)

Add section before "## Contents of the Rig":

```nix
${optionalString (rig.promptCommands != {}) ''
  ## Prompt Commands

  This rig provides prompt commands (slash commands in Claude Code):

  ${concatStringsSep "\n" (
    mapAttrsToList (name: tmpl:
      "- `/${tmpl.namespacedName}` - ${tmpl.description}${
        optionalString (tmpl.arguments != [])
          " (args: ${concatMapStringsSep ", " (a: a.name) tmpl.arguments})"
      }"
    ) rig.promptCommands
  )}

  Commands stored in `promptCommands/<riglet>/<command>.md`
''}
```

**Rationale**:
- Shows available commands with descriptions
- Lists expected arguments
- Generic paths (not harness-specific)

## Critical Files to Modify

1. **lib/rigletSchema.nix**
   - Add `promptCommands` option under `options.riglets.<rigletname>` (alongside `tools`, `docs`, `configFiles`)

2. **lib/buildRig.nix**
   - Add `promptCommands` collection (similar to how other rig capabilities are collected)
   - Add `promptCommandRoot` derivation
   - Add both to `baseRig` attrset

3. **lib/buildRig.nix** (in `home` derivation)
   - Add `promptCommands/` symlink to `promptCommandRoot`

4. **lib/genManifest.nix**
   - Add "## Prompt Commands" section (before "## Contents of the Rig")

5. **riglets/claude-code.nix** (Phase 1)
   - Generate Claude Code plugin structure with `rig.promptCommands`
   - Load plugin via `--plugin-dir` flag

6. **riglets/opencode.nix** (Phase 2)
   - Similar pattern to claude-code, but via the already generated json config file

7. **riglets/cursor-agent.nix** (Phase 3)
   - Simpler generation (no frontmatter - check what cursor-agent supports at the time of implementation)
   - Written to existing CURSOR_CONFIG_DIR

8. **riglets/copilot-cli.nix** (Phase 4)
   - Just print a warning if the rig contains prompt commands that these are not supported by Copilot CLI yet

## Implementation Steps

1. **Add schema** - Define `promptCommands` submodule in rigletSchema.nix with fields supporting all harnesses
2. **Add collection** - Collect commands and build derivation in buildRig.nix
3. **Add to home** - Symlink `promptCommands/` folder
4. **Update manifest** - Show available commands in RIG.md
5. **Phase 1**: Update Claude Code entrypoint - Add slash command generation
6. **Phase 2**: OpenCode entrypoint (similar frontmatter, add `agent` field)
7. **Phase 3**: Cursor Agent entrypoint (no frontmatter, just content)
8. **Phase 4**: Copilot CLI (blocked on upstream feature request)

## Verification Plan

1. **Build rig**:
   ```bash
   nix build ".#rigs.x86_64-linux.default.home"
   ls -la result/promptCommands/
   ```

2. **Verify structure**:
   ```
   result/promptCommands/
   └── jj-workflow/
       ├── commit.md
       └── sync.md
   ```

3. **Check metadata**:
   ```bash
   nix eval --json ".#rigs.x86_64-linux.default.promptCommands"
   # Should show structured metadata
   ```

4. **Check manifest**:
   ```bash
   cat result/RIG.md | grep -A 10 "Prompt Commands"
   ```

5. **Test in Claude Code**:
   - Run `rigup run ".#default"` (uses updated claude-code entrypoint with plugin)
   - In Claude Code session, type `/` to see available commands
   - Use `/rig:command-name` (commands namespaced by plugin)
   - Verify frontmatter is properly generated from Nix metadata
   - Test with arguments (e.g., `/rig:commit "feat: add feature"`)

6. **Test other harnesses**:
   - OpenCode: Similar testing once entrypoint is updated
   - Cursor Agent: Test after adding support
   - Copilot CLI: N/A (no support)

## Design Decisions (Finalized)

1. **Architecture**: ✅ Nix metadata with harness-specific translation via entrypoints
2. **Schema**: ✅ Typed Nix submodule (not opaque strings)
3. **Storage**: ✅ Generic `promptCommands/` folder (not `.claude/commands/`)
4. **Exposure**: ✅ Via entrypoint config (not local file modification)
5. **Namespace**: ✅ By riglet (`riglet-name/template-name`)
6. **Examples**: ✅ Minimal initial implementation

## Benefits

- **Type-safe**: Nix validates metadata at build time
- **Declarative**: Metadata defined alongside commands
- **Harness-agnostic**: Generic storage, harness-specific translation
- **No local file modification**: Entrypoints generate config
- **Composable**: Commands from all riglets collected
- **Discoverable**: Listed in manifest with full metadata

---

This follows rigup's architecture principles.
