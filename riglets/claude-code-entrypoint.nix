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
    let
      manifestPath = rig.genManifest { shownDocRoot = "$RIG_DOCS"; };
    in
    (pkgs.formats.json { }).generate "${rig.name}-claude-code-settings.json" {
      # Grant read access to specific Nix store paths that Claude Code needs
      permissions.allow = [
        "Read(${manifestPath})"           # The RIG.md manifest file
        "Read(${rig.docRoot}/**)"         # All documentation files
        "Read(${rig.configRoot}/**)"      # All config files (XDG_CONFIG_HOME)
      ];

      hooks.SessionStart = [
        {
          matcher = "startup";
          hooks = [
            {
              type = "command";
              command = "cat ${manifestPath}";
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
      export PATH="${rig.toolRoot}/bin:$(dirname "$0"):$PATH"
      export XDG_CONFIG_HOME="${rig.configRoot}"
      export RIG_DOCS="${rig.docRoot}"

      exec ${pkgs.lib.getExe claude-code} --settings "${mkSettings rig}" "$@"
    '';

  config.riglets.claude-code-entrypoint = {
    meta = {
      description = "Claude Code integration: entrypoint to launch Claude Code with rig context";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
