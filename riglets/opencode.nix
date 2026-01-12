self:
{
  pkgs,
  system,
  lib,
  config,
  ...
}:
let
  inherit (self.inputs.llm-agents.packages.${system}) opencode;
  inherit (lib) mkOption types;
in
{
  options.opencode = {
    # OpenCode may want to write to its config directory.
    # This folder can hold conversation history, etc., so we use a user-provided path
    persistentConfigDir = mkOption {
      type = types.pathWith { inStore = false; };
      description = "Persistent folder in which to store the generated config for OpenCode";
      # A fake default to allow this riglet to be checked in isolation
      default = "/home/fake-user-sdf45llk431/.config/opencode";
    };
  };

  # Define the entrypoint for this rig - launches OpenCode with rig context
  config.entrypoint =
    rig:
    let
      manifestPath = rig.manifest.override { shownDocRoot = "$RIG_DOCS"; };

      # OpenCode config with permissions and MCP servers
      opencodeConfigJson = (pkgs.formats.json { }).generate "${rig.name}-opencode-config.json" {
        instructions = [
          manifestPath
        ];

        # Grant read access to specific Nix store paths that OpenCode needs
        permission = {
          bash = pkgs.lib.listToAttrs (
            map (cmd: {
              name = "${cmd} *";
              value = "allow";
            }) rig.allExeNames
          );
        };

        # Configure MCP servers
        mcp = pkgs.lib.mapAttrs (
          name: s:
          {
            # OpenCode uses "local" for command-based servers and "remote" for URL-based servers
            type = if s.resolvedCommand != null then "local" else "remote";
            enabled = true;
          }
          // pkgs.lib.optionalAttrs (s.resolvedCommand != null) { command = [ s.resolvedCommand ]; }
          // pkgs.lib.optionalAttrs (s.url != null) { inherit (s) url; }
        ) rig.mcpServers;
      };
    in
    # Return a folder derivation with bin/ subfolder
    pkgs.writeShellScriptBin "opencode" ''
      set -euo pipefail

      warn() {
        printf "\033[0;33m%s\n\033[0m" "$1" >&2
      }

      # OpenCode may try to write to its config, so we copy it to a writeable directory
      export OPENCODE_CONFIG_DIR="${config.opencode.persistentConfigDir}"
      export OPENCODE_CONFIG="$OPENCODE_CONFIG_DIR/config.json"
      mkdir -p "$OPENCODE_CONFIG_DIR"

      export PATH="${rig.toolRoot}/bin:$PATH"
      export RIG_DOCS="${rig.docRoot}"
      # Exported for convenience
      export RIG_MANIFEST="${manifestPath}"

      cp "${opencodeConfigJson}" "$OPENCODE_CONFIG"
      chmod +w "$OPENCODE_CONFIG"
      warn "Overwrote $OPENCODE_CONFIG"

      exec ${pkgs.lib.getExe opencode} "$@"
    '';

  config.riglets.opencode = {
    meta = {
      description = "Launch OpenCode with rig context";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
