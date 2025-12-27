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
      manifestPath = rig.genManifest { shownDocRoot = "$RIG_DOCS"; };

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
    in
    # Return a folder derivation with bin/ subfolder
    pkgs.writeShellScriptBin "copilot" ''
      export PATH="${wrappedTools}/bin:$PATH"
      export RIG_DOCS="${rig.docRoot}"
      export RIG_MANIFEST="${manifestPath}"

      printf "\033[0;33m%s\n\033[0m" "NOTE: copilot-cli doesn't support startup hooks, first instruct your agent to read \$RIG_MANIFEST" >&2

      exec ${pkgs.lib.getExe copilot-cli} \
        ${pkgs.lib.concatStringsSep " " (map (t: "--allow-tool 'shell(${t}:*)'") rig.commandNames)} \
        --add-dir "${rig.docRoot}" \
        --add-dir "${rig.toolRoot}" \
        --add-dir "${rig.configRoot}" \
        "$@"
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
