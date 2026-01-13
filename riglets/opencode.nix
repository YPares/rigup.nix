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
    # See https://opencode.ai/docs/lsp/#built-in
    disableLspDownload = mkOption {
      type = types.bool;
      description = "Disable auto-downloads of LSP servers";
      default = false;
    };

    lspServers = mkOption {
      description = "LSP servers to be used by the agent";
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            disabled = mkOption {
              type = types.bool;
              description = "Disable this LSP";
              default = false;
            };
            command = mkOption {
              type = types.nullOr types.package;
              description = "Which package to run. 'null' to use default opencode support for this LSP";
              default = null;
            };
            extensions = mkOption {
              type = types.nullOr (types.listOf types.str);
              description = "Which file extensions to use this LSP server with (including '.' prefixes). 'null' to use default opencode support for this LSP";
              default = null;
            };
            initialization = mkOption {
              type = types.nullOr (types.attrsOf types.anything);
              description = "Initialization options to send to the LSP server";
              default = null;
            };
          };
        }
      );
    };
  };

  # Define the entrypoint for this rig - launches OpenCode with rig context
  config.entrypoint =
    rig:
    let
      manifestPath = rig.manifest.override { shownDocRoot = "$RIG_DOCS"; };

      # OpenCode config with permissions and MCP servers
      opencodeConfigJson = (pkgs.formats.json { }).generate "opencode-config.json" {
        "$schema" = "https://opencode.ai/config.json";

        instructions = [
          manifestPath
        ];

        # Grant read access to specific Nix store paths that OpenCode needs
        permission = {
          bash = lib.listToAttrs (
            map (cmd: {
              name = "${cmd} *";
              value = "allow";
            }) rig.allExeNames
          );
        };

        lsp = lib.mapAttrs (
          _name: s:
          lib.filterAttrs (_: x: x != null) s
          // lib.optionalAttrs (s.command != null) {
            command = [ (lib.getExe s.command) ];
          }
        ) config.opencode.lspServers;
      };
    in
    # Return a folder derivation with bin/ subfolder
    pkgs.writeShellScriptBin "opencode" ''
      set -euo pipefail

      warn() {
        printf "\033[0;33m%s\n\033[0m" "$1" >&2
      }

      export PATH="${rig.toolRoot}/bin:$PATH"
      export RIG_DOCS="${rig.docRoot}"
      # Exported for convenience
      export RIG_MANIFEST="${manifestPath}"

      export OPENCODE_CONFIG="${opencodeConfigJson}"

      ${lib.optionalString config.opencode.disableLspDownload "export OPENCODE_DISABLE_LSP_DOWNLOAD=true"}

      exec ${lib.getExe opencode} "$@"
    '';

  config.riglets.opencode = {
    meta = {
      description = "Launch OpenCode with rig context";
      intent = "base";
      disclosure = "none";
      status = "stable";
      version = "0.1.0";
    };
  };
}
