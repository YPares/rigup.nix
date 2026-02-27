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
  imports = [
    self.riglets.models
    self.riglets.lsp-servers
  ];

  options.opencode = {
    # See https://opencode.ai/docs/lsp/#built-in
    disableLspDownload = mkOption {
      type = types.bool;
      description = "Disable auto-downloads of LSP servers";
      default = false;
    };
  };

  # OpenCode supports using LSP servers.
  #
  # Riglets can test config.lspServersEnabled to know whether they can add lsp server config to the rig
  config.lspServersEnabled = lib.mkDefault true;

  # Define the entrypoint for this rig - launches OpenCode with rig context
  config.entrypoint =
    rig:
    let
      manifestPath = rig.manifest.override { shownDocRoot = "$RIG_DOCS"; };

      toModelId =
        x:
        if x.modelId != null && x.providerId == null then
          throw ''
            If modelId is set, then providerId must be set too
          ''
        else
          "${x.providerId}/${x.modelId}";

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

          agent = lib.mapAttrs (_agentName: mdl: { model = toModelId mdl; }) config.models.specialized;

          disabled_providers = config.models.providers.disabled;
        }
        // lib.optionalAttrs (config.models.providers.enabled != null) {
          enabled_providers = config.models.providers.enabled;
        }
        // lib.optionalAttrs (config.models.default.modelId != null) {
          model = toModelId config.models.default;
        }
        // lib.optionalAttrs config.lspServersEnabled {
          lsp = lib.mapAttrs (
            _name: s:
            lib.filterAttrs (_: x: x != null) s
            // lib.optionalAttrs (s.command != null) {
              command = [ (lib.getExe s.command) ];
            }
          ) config.lspServers;
        }
      );
    in
    # Return a folder derivation with bin/ subfolder
    pkgs.writeShellScriptBin "opencode" ''
      set -euo pipefail

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
