self:
{
  pkgs,
  system,
  config,
  riglib,
  ...
}:
let
  inherit (self.inputs.llm-agents.packages.${system}) cursor-agent;
  inherit (pkgs.lib) mkOption types;
in
{
  # Exposed because this is a mandatory option for cursor's cli-config.json
  options.cursor-agent = {
    # cursor-agent wants its config to be writeable.
    # This folder will also hold conversation history, etc., so the only safe place is a user-provided path
    persistentConfigDir = mkOption {
      type = types.pathWith { inStore = false; };
      description = "Persistent folder in which to store the generated config for cursor-agent";
      # A fake default to allow this riglet to be checked in isolation
      default = "/home/fake-user-sdf45llk431/.cursor";
    };

    # Exposed because it _needs_ to be present so cursor-agent considers the config to be valid
    editor.vimMode = riglib.options.flag "Activate vim mode for cursor-agent";
  };

  # Define the entrypoint for this rig - launches Cursor Agent with rig context
  config.entrypoint =
    rig:
    let
      inherit (pkgs) lib;
      cliConfigJson = (pkgs.formats.json { }).generate "cli-config.json" {
        # https://cursor.com/docs/cli/reference/configuration#required-fields
        inherit (config.cursor-agent) editor;
        version = 1;
        permissions.allow =
          # Grant read access to rig documentation and config
          [
            "Read(${rig.docRoot}/**)" # All documentation files
            "Read(${rig.configRoot}/**)" # All config files
            "Read(${rig.toolRoot}/**)" # Tool files (for inspecting share/, lib/, etc.)
          ]
          ++ map (cmd: "Shell(${cmd})") rig.allExeNames; # Allow executing all rig tools
        permissions.deny = [ ];
      };

      # MCP servers configuration
      mcpConfigJson = (pkgs.formats.json { }).generate "mcp.json" {
        mcpServers = pkgs.lib.mapAttrs (
          name: s:
          {
            type = s.transport;
          }
          // pkgs.lib.optionalAttrs (s.resolvedCommand != null) { command = s.resolvedCommand; }
          // pkgs.lib.optionalAttrs (s.url != null) { inherit (s) url; }
          // pkgs.lib.optionalAttrs (s.headers != { }) { inherit (s) headers; }
        ) rig.mcpServers;
      };
    in
    # Return a folder derivation with bin/ subfolder
    pkgs.writeShellScriptBin "cursor-agent" ''
      set -euo pipefail

      warn() {
        printf "\033[0;33m%s\033[0m\n" "$1" >&2
      }

      err() {
        printf "\033[0;31m%s\033[0m\n" "$1" >&2
      }

      gitignored () {
        ${lib.getExe pkgs.git} check-ignore "$1" > /dev/null
      }

      cp-if-ignored() {
        src="$1"
        dest="$2"
        if gitignored "$dest"; then
          cp "$src" "$dest"
          chmod +w "$dest"
          warn "Overwrote $dest"
        else
          err "$dest is not gitignored. Refusing to copy"
          exit 1
        fi
      }

      export CURSOR_CONFIG_DIR="${config.cursor-agent.persistentConfigDir}"

      if [ ! -d "$CURSOR_CONFIG_DIR" ]; then
        err "$CURSOR_CONFIG_DIR does not exist. Please create it first"
        exit 1
      fi

      mkdir -p "$CURSOR_CONFIG_DIR/rules"

      export PATH="${rig.toolRoot}/bin:$PATH"
      export RIG_DOCS="${rig.docRoot}"
      export RIG_MANIFEST="$CURSOR_CONFIG_DIR/rules/rig-manifest.mdc"

      cp-if-ignored "${cliConfigJson}" "$CURSOR_CONFIG_DIR/cli-config.json"
      cp-if-ignored "${mcpConfigJson}" "$CURSOR_CONFIG_DIR/mcp.json"
      ${lib.optionalString (rig.promptCommands != { }) ''
        mkdir -p "$CURSOR_CONFIG_DIR/commands"
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (cmdName: cmd: ''
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
            rig.manifest.override {
              manifestFileName = "rig-manifest.mdc";
              shownDocRoot = "$RIG_DOCS";
            }
          )
        }        
      ''}" "$RIG_MANIFEST"

      warn "IMPORTANT: Unless $CURSOR_CONFIG_DIR is your project's top-level .cursor/ folder, instruct first your agent to read $RIG_MANIFEST"

      ${pkgs.lib.getExe cursor-agent} "$@"
    '';

  config.riglets.cursor-agent = {
    meta = {
      description = "Launch Cursor Agent with rig context";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
