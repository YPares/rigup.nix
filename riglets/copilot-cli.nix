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

      # Wrap all rig tools to inject environment variables
      # This way copilot-cli itself doesn't see XDG_CONFIG_HOME (needs writable config),
      # but when it invokes rig tools, they get the read-only rig config
      wrappedTools = riglib.wrapWithEnv {
        name = "${rig.name}-wrapped-tools";
        tools = [ rig.toolRoot ];
        env = {
          XDG_CONFIG_HOME = rig.configRoot;
        };
      };

      copilotArgs =
        with pkgs.lib;
        concatMap (cmd: [
          "--allow-tool"
          "shell(${cmd}:*)"
        ]) rig.commandNames
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
    pkgs.writeShellScriptBin "copilot" ''
      export PATH="${wrappedTools}/bin:$PATH"

      # copilot-cli automatically loads AGENTS.md from custom instruction directories
      # COPILOT_CUSTOM_INSTRUCTIONS_DIRS is a comma-separated list of additional dirs
      export COPILOT_CUSTOM_INSTRUCTIONS_DIRS="${instructionsDir}"

      # For later reference, if needed
      export RIG_MANIFEST="${instructionsDir}/AGENTS.md"

      exec ${pkgs.lib.getExe copilot-cli} ${pkgs.lib.escapeShellArgs copilotArgs} "$@"
    '';

  config.riglets.copilot-cli = {
    meta = {
      description = "Provides entrypoint to launch Copilot CLI with rig context";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
