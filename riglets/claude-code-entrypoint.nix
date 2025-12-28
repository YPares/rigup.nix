self:
{
  pkgs,
  system,
  ...
}:
let
  inherit (self.inputs.llm-agents.packages.${system}) claude-code;

  # Extract list of executable names from toolRoot/bin for Bash permissions
  # Uses IFD (Import From Derivation) to inspect the built toolRoot
  listToolCommands = toolRoot:
    let
      # Derivation that lists all executables in toolRoot/bin
      commandListFile = pkgs.runCommand "list-rig-commands" {} ''
        # List all executable files in bin/, output just the basenames
        if [ -d "${toolRoot}/bin" ]; then
          cd "${toolRoot}/bin"
          for cmd in *; do
            if [ -x "$cmd" ] && [ -f "$cmd" ]; then
              echo "$cmd"
            fi
          done > "$out"
        else
          touch "$out"
        fi
      '';
      # Read the file content and split into list (IFD)
      commandsText = builtins.readFile commandListFile;
      commandsList = pkgs.lib.splitString "\n" commandsText;
    in
    # Filter out empty strings
    builtins.filter (cmd: cmd != "") commandsList;

  mkSettings =
    rig:
    let
      manifestPath = rig.genManifest { shownDocRoot = "$RIG_DOCS"; };

      # Get list of all commands in the rig's toolRoot
      rigCommands = listToolCommands rig.toolRoot;

      # Generate Bash permissions for each rig tool: "Bash(command:*)"
      bashPermissions = map (cmd: "Bash(${cmd}:*)") rigCommands;
    in
    (pkgs.formats.json { }).generate "${rig.name}-claude-code-settings.json" {
      # Grant read access to specific Nix store paths that Claude Code needs
      permissions.allow = [
        "Read(${manifestPath})"           # The RIG.md manifest file
        "Read(${rig.docRoot}/**)"         # All documentation files
        "Read(${rig.configRoot}/**)"      # All config files (XDG_CONFIG_HOME)
        "Read(${rig.toolRoot}/**)"        # Tool files (for inspecting share/, lib/, etc.)
      ] ++ bashPermissions;               # Allow executing all rig tools

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
