self:
{
  pkgs,
  system,
  riglib,
  ...
}:
let
  inherit (self.inputs.llm-agents.packages.${system}) copilot-cli;
in
{
  # Define the entrypoint for this rig - launches Copilot CLI with rig context
  config.entrypoint =
    rig:
    let
      instructionsDir = riglib.writeFileTree {
        "AGENTS.md" = rig.manifest.override {
          manifestFileName = "AGENTS.md";
          shownDocRoot = "./docs";
        };
        docs = rig.docRoot;
      };

      copilotArgs =
        with pkgs.lib;
        concatMap (cmd: [
          "--allow-tool"
          "shell(${cmd}:*)"
        ]) rig.allExeNames
        ++
          concatMap
            (dir: [
              "--add-dir"
              dir
            ])
            [
              instructionsDir
              rig.toolRoot
              rig.configRoot
            ];
    in
    # Return a folder derivation with bin/ subfolder
    #
    # TODO: Not great. We overwrite the project's .vscode/mcp.json
    # To be improved
    pkgs.writeShellScriptBin "copilot" ''
      set -euo pipefail

      warn() {
        printf "> \033[0;33m%s\033[0m\n" "$1" >&2
      }

      export PATH="${rig.toolRoot}/bin:$PATH"
      # COPILOT_CUSTOM_INSTRUCTIONS_DIRS is a comma-separated list of additional dirs to search for AGENTS.md files.
      # We directly use the rig's manifest as such.
      export COPILOT_CUSTOM_INSTRUCTIONS_DIRS="${instructionsDir}"
      # For later reference, if needed
      export RIG_MANIFEST="${instructionsDir}/AGENTS.md"

      ${pkgs.lib.optionalString (rig.promptCommands != { }) ''
        warn "github-cli does not support custom commands"
        warn "  Rig's prompt commands are ignored"
      ''}

      ${pkgs.lib.optionalString (rig.mcpServers != { }) ''
        warn "github-cli does not support setting MCP servers outside of your XDG_CONFIG_HOME"
        warn "  Rig's MCP config is ignored"
      ''}

      ${pkgs.lib.optionalString (rig.denyRules != { }) ''
        warn "github-cli does not support deny rules via CLI arguments"
        warn "  Rig's deny rules are ignored"
      ''}

      exec ${pkgs.lib.getExe copilot-cli} ${pkgs.lib.escapeShellArgs copilotArgs} "$@"
    '';

  config.riglets.copilot-cli = {
    meta = {
      description = "Launch Copilot CLI with rig context";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
