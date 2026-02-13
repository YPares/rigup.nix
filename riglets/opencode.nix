self:
{
  pkgs,
  system,
  lib,
  config,
  riglib,
  ...
}:
let
  inherit (self.inputs.llm-agents.packages.${system}) opencode;
  inherit (lib) mkOption types;
in
{
  imports = [ self.riglets.models ];

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
      opencodeConfigJson = riglib.toJSON (
        {
          "$schema" = "https://opencode.ai/config.json";

          instructions = [
            manifestPath
          ];

          # Grant read access to specific Nix store paths that OpenCode needs
          permission = {
            # external_directory is needed for paths outside the working directory
            external_directory = {
              "${builtins.unsafeDiscardStringContext rig.docRoot}/**" = "allow";
              "${builtins.unsafeDiscardStringContext rig.toolRoot}/**" = "allow";
              "${builtins.unsafeDiscardStringContext rig.configRoot}/**" = "allow";
            };
            bash =
              lib.listToAttrs (
                map (cmd: {
                  name = "${cmd} *";
                  value = "allow";
                }) rig.allExeNames
              )
              # Add deny rules for specific tool subcommands
              # OpenCode uses wildcard patterns, so we add " *" suffix
              // lib.listToAttrs (
                lib.flatten (
                  lib.mapAttrsToList (
                    tool: patterns:
                    map (pattern: {
                      name = "${tool} ${pattern} *";
                      value = "deny";
                    }) patterns
                  ) rig.denyRules
                )
              );
          };

          lsp = lib.mapAttrs (
            _name: s:
            lib.filterAttrs (_: x: x != null) s
            // lib.optionalAttrs (s.command != null) {
              command = [ (lib.getExe s.command) ];
            }
          ) config.opencode.lspServers;

          mcp = lib.mapAttrs (
            name: def:
            if def ? command then
              {
                enabled = true;
                type = "local";
                command = [ (lib.getExe def.command) ];
              }
            else
              {
                enabled = true;
                type = "remote";
                inherit (def) url;
              }
              // lib.optionalAttrs (def.headers != { }) { inherit (def) headers; }
          ) rig.mcpServers;

          command = lib.mapAttrs (
            name: cmd:
            {
              template = cmd.template;
              description = cmd.description;
            }
            // lib.optionalAttrs cmd.useSubAgent { subtask = true; }
          ) (lib.concatMapAttrs (k: v: { "rig:${k}" = v; }) rig.promptCommands);
        }
        // lib.optionalAttrs (config.models.default.modelId != null) {
          model =
            if config.models.default.providerId == null then
              throw ''
                If models.default.modelId is set, then models.default.providerId must be too
              ''
            else
              "${config.models.default.providerId}/${config.models.default.modelId}";
        }
        // lib.optionalAttrs (config.models.providers.disabled != null) {
          disabled_providers = config.models.providers.disabled;
        }
        // lib.optionalAttrs (config.models.providers.enabled != null) {
          enabled_providers = config.models.providers.enabled;
        }
      );
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
