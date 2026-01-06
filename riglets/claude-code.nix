self:
{
  pkgs,
  system,
  ...
}:
let
  inherit (self.inputs.llm-agents.packages.${system}) claude-code;
in
{
  # Define the entrypoint for this rig - launches Claude Code with rig context
  config.entrypoint =
    rig:
    let
      manifestPath = rig.manifest.override { shownDocRoot = "$RIG_DOCS"; };

      settingsJson = (pkgs.formats.json { }).generate "${rig.name}-settings.json" {
        # Grant read access to specific Nix store paths that Claude Code needs
        permissions.allow = [
          "Read(${manifestPath})" # The RIG.md manifest file
          "Read(${rig.docRoot}/**)" # All documentation files
          "Read(${rig.configRoot}/**)" # All config files
          "Read(${rig.toolRoot}/**)" # Tool files (for inspecting share/, lib/, etc.)
        ]
        ++ map (cmd: "Bash(${cmd}:*)") rig.allExeNames; # Allow executing all rig tools

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
    # Return a folder derivation with bin/ subfolder
    pkgs.writeShellScriptBin "claude" ''
      export PATH="${rig.toolRoot}/bin:$PATH"
      export RIG_DOCS="${rig.docRoot}"
      # For later reference, if needed
      export RIG_MANIFEST="${manifestPath}"

      exec ${pkgs.lib.getExe claude-code} --settings "${settingsJson}" "$@"
    '';

  config.riglets.claude-code = {
    meta = {
      description = "Provides entrypoint to launch Claude Code with rig context";
      intent = "base";
      disclosure = "none";
      status = "stable";
      version = "0.1.0";
    };
  };
}
