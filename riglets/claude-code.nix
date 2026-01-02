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
      manifestPath = rig.genManifest { shownDocRoot = "$RIG_DOCS"; };

      settingsJson = (pkgs.formats.json { }).generate "${rig.name}-settings.json" {
        # Grant read access to specific Nix store paths that Claude Code needs
        permissions.allow = [
          "Read(${manifestPath})" # The RIG.md manifest file
          "Read(${rig.docRoot}/**)" # All documentation files
          "Read(${rig.configRoot}/**)" # All config files (XDG_CONFIG_HOME)
          "Read(${rig.toolRoot}/**)" # Tool files (for inspecting share/, lib/, etc.)
        ]
        ++ map (cmd: "Bash(${cmd}:*)") rig.commandNames; # Allow executing all rig tools

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
      # Unlike e.g. copilot-cli, claude-code doesn't use the XDG_CONFIG_HOME env var,
      # so we don't need to wrap the tools and can directly set PATH to toolRoot and XDG_CONFIG_HOME
      # to configRoot
      export PATH="${rig.toolRoot}/bin:$PATH"
      export XDG_CONFIG_HOME="${rig.configRoot}"
      export RIG_DOCS="${rig.docRoot}"
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
