self:
{
  pkgs,
  system,
  lib,
  config,
  ...
}:
let
  inherit (self.inputs.llm-agents.packages.${system}) pi;
  cfg = config.models;
in
{
  imports = [
    self.riglets.models
  ];

  options.pi.extensions = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "A list of URLs to Pi extensions to use";
    default = [ ];
  };

  # Define the entrypoint for this rig - launches Pi with rig context
  config.entrypoint =
    rig:
    let
      manifestPath = rig.manifest.override { shownDocRoot = "$RIG_DOCS"; };

      # Generate prompt template files from riglet promptCommands
      # Each becomes a .md file that Pi can load via --prompt-template
      promptTemplateDir =
        if rig.promptCommands != { } then
          pkgs.runCommandLocal "rig-pi-prompt-templates" { } ''
            mkdir -p $out
            ${lib.concatMapAttrsStringSep "\n" (name: cmd: ''
              cat > $out/rig:${name}.md <<'CMDEOF'
              ---
              description: ${cmd.description}
              ---

              ${cmd.template}
              CMDEOF
            '') rig.promptCommands}
          ''
        else
          null;
    in
    # Return a folder derivation with bin/ subfolder
    pkgs.writeShellApplication {
      name = "pi";
      runtimeInputs = [ pkgs.nodejs ];
      text = ''
        set -euo pipefail

        warn() {
          printf "> \033[0;33m%s\033[0m\n" "$1" >&2
        }

        export PATH="${rig.toolRoot}/bin:$PATH"
        export RIG_DOCS="${rig.docRoot}"
        # For later reference, if needed
        export RIG_MANIFEST="${manifestPath}"

        ${
          pkgs.lib.optionalString (rig.mcpServers != { }) ''
            warn "pi does not support MCP servers"
            warn "  Rig's MCP config is ignored"
          ''
        }${
          pkgs.lib.optionalString (rig.denyRules != { }) ''
            warn "pi does not support deny rules"
            warn "  Rig's deny rules are ignored"
          ''
        }${
          pkgs.lib.optionalString (cfg.specialized != { }) ''
            warn "pi does not support specialized agents"
            warn "  Rig's specialized model config is ignored"
          ''
        }

        exec ${lib.getExe pi} \
          --append-system-prompt "$(cat ${manifestPath})" \
          ${lib.optionalString (promptTemplateDir != null) "--prompt-template ${promptTemplateDir}"} \
          ${lib.concatStringsSep " " (map (ext: "--extension ${ext}") config.pi.extensions)} \
          ${lib.optionalString (cfg.default.providerId != null) "--provider ${cfg.default.providerId}"} \
          ${lib.optionalString (cfg.default.modelId != null) "--model ${cfg.default.modelId}"} \
          "$@"
      '';
    };

  config.riglets.pi = {
    meta = {
      description = "Launch Pi with rig context";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.2.0";
    };
  };
}
