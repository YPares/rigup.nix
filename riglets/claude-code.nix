self:
{
  pkgs,
  system,
  ...
}:
let
  inherit (self.inputs.llm-agents.packages.${system}) claude-code;

  mkSettings =
    rig:
    (pkgs.formats.json { }).generate "${rig.name}-claude-code-settings.json" {
      hooks.SessionStart = [
        {
          matcher = "startup";
          hooks = [
            {
              type = "command";
              command = "cat ${rig.genManifest { shownDocRoot = "$RIG_DOCS"; }}";
            }
          ];
        }
      ];
    };
in
{
  # Define the entrypoint for this rig - launches Claude Code with rig context
  config.entrypoint =
    rig:
    # Return a folder derivation with bin/ subfolder
    pkgs.writeShellScriptBin "claude" ''
      #export PATH="${rig.toolRoot}:$(dirname "$0"):$PATH"
      #export XDG_CONFIG_HOME="${rig.configRoot}"
      #export RIG_DOCS="${rig.docRoot}"

      ${pkgs.lib.getExe claude-code} --settings "${mkSettings rig}" "$@"
    '';

  config.riglets.claude-code = {
    meta = {
      description = "claude-code integration - entrypoint to launch claude with rig context";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
