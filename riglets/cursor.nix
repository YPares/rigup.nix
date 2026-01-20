self:
{
  pkgs,
  system,
  config,
  riglib,
  ...
}:
let
  inherit (pkgs) lib;
in
{
  imports = [ self.riglets.models ];

  options.cursor = {
    # To setup a project to use with Cursor IDE
    justSetupProject = riglib.options.flag "Only set up .cursor/ in CWD, don't run cursor-agent";

    # Exposed because it _needs_ to be present so cursor-agent considers the config to be valid
    editor.vimMode = riglib.options.flag "Activate vim mode for cursor-agent";
  };

  config.entrypoint =
    rig:
    let
      cliConfigJson = riglib.toJSON {
        # https://cursor.com/docs/cli/reference/configuration#required-fields
        inherit (config.cursor) editor;
        version = 1;
        permissions.allow =
          # Grant read access to rig documentation and config
          [
            "Read(${rig.docRoot}/**)" # All documentation files
            "Read(${rig.configRoot}/**)" # All config files
            "Read(${rig.toolRoot}/**)" # Tool files (for inspecting share/, lib/, etc.)
          ]
          ++ map (cmd: "Shell(${cmd})") rig.allExeNames; # Allow executing all rig tools

        # Add deny rules for specific tool subcommands
        permissions.deny = lib.flatten (
          lib.mapAttrsToList (
            tool: patterns: map (pattern: "Shell(${tool} ${pattern})") patterns
          ) rig.denyRules
        );
      };

      # MCP servers configuration
      mcpConfigJson = riglib.toJSON {
        mcpServers = lib.mapAttrs (
          name: s:
          {
            type = s.transport;
          }
          // lib.optionalAttrs (s.resolvedCommand != null) { command = s.resolvedCommand; }
          // lib.optionalAttrs (s.url != null) { inherit (s) url; }
          // lib.optionalAttrs (s.headers != { }) { inherit (s) headers; }
        ) rig.mcpServers;
      };

      scriptName = if config.cursor.justSetupProject then "cursor-setup" else "cursor-agent";
    in
    # Return a folder derivation with bin/ subfolder
    pkgs.writeShellScriptBin scriptName ''
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
        src="$1"
        dest="$2"
        if is-ignored "$dest"; then
          cp "$src" "$dest"
          chmod +w "$dest"
          info "Overwrote $dest"
        else
          err "$dest is not gitignored. Will not write it"
          exit 1
        fi
      }

      CURSOR_CONFIG_DIR=".cursor"

      if [ ! -d "$CURSOR_CONFIG_DIR" ]; then
        err "$CURSOR_CONFIG_DIR folder does not exist. Create it first"
        exit 1
      fi

      mkdir -p "$CURSOR_CONFIG_DIR/rules"

      ${
        if config.cursor.justSetupProject then
          ''
            cp-if-ignored "${pkgs.writeText "rig-activate.sh" ''
              export PATH="${rig.toolRoot}/bin:$PATH"
            ''}" "$CURSOR_CONFIG_DIR/rig-activate.sh"
          ''
        else
          ''
            export PATH="${rig.toolRoot}/bin:$PATH"
            export RIG_DOCS="${rig.docRoot}"
            cp-if-ignored "${cliConfigJson}" "$CURSOR_CONFIG_DIR/cli-config.json"
          ''
      }

      export RIG_MANIFEST="$CURSOR_CONFIG_DIR/rules/rig-manifest.mdc"

      cp-if-ignored "${mcpConfigJson}" "$CURSOR_CONFIG_DIR/mcp.json"

      ${lib.optionalString (rig.promptCommands != { }) ''
        mkdir -p "$CURSOR_CONFIG_DIR/commands"
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (cmdName: cmd: ''
            ${lib.optionalString cmd.useSubAgent ''
              warn "Ignoring useSubAgent in ${cmdName} (cursor does not support running commands in subagents)"
            ''}
            cmdPath="$CURSOR_CONFIG_DIR/commands/rig:${cmdName}.md"
            cp-if-ignored "${pkgs.writeText "cursor-command.md" ''
              <!-- ${cmd.description} -->

              ${cmd.template}
            ''}" "$cmdPath"
          '') rig.promptCommands
        )}
      ''}

      cp-if-ignored "${pkgs.writeText "rig-manifest.mdc" ''
        ---
        alwaysApply: true
        ---

        ${
          builtins.readFile (
            rig.manifest.override (
              {
                manifestFileName = "rig-manifest.mdc";
              }
              // (
                if config.cursor.justSetupProject then
                  {
                    shownActivationScript = ".cursor/rig-activate.sh";
                  }
                else
                  {
                    shownDocRoot = "$RIG_DOCS";
                  }
              )
            )
          )
        }        
      ''}" "$RIG_MANIFEST"

      ${
        if config.cursor.justSetupProject then
          ''
            info "Project set up for use with Cursor"
          ''
        else
          ''
            ${lib.getExe self.inputs.llm-agents.packages.${system}.cursor-agent} ${
              lib.optionalString (
                config.models.default.modelId != null
              ) "--model ${lib.escapeShellArg config.models.default.modelId}"
            } "$@"
          ''
      }
    '';

  config.riglets.cursor = {
    meta = {
      description = "Set up project for use with cursor, and optionally launch cursor-agent";
      intent = "base";
      disclosure = "none";
      status = "stable";
      version = "0.1.0";
    };
  };
}
