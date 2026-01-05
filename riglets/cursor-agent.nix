self:
{
  pkgs,
  system,
  riglib,
  config,
  ...
}:
let
  inherit (self.inputs.llm-agents.packages.${system}) cursor-agent;
in
{
  # Exposed because this is a mandatory option for cursor's cli-config.json
  options.cursor-agent.editor.vimMode = pkgs.lib.mkOption {
    type = pkgs.lib.types.bool;
    description = "Activate vim mode for cursor-agent";
    default = false;
  };

  # Define the entrypoint for this rig - launches Cursor Agent with rig context
  config.entrypoint =
    rig:
    let
      manifestPath = rig.manifest.override { shownDocRoot = "$RIG_DOCS"; };

      cliConfigJson = (pkgs.formats.json { }).generate "${rig.name}-cli-config.json" {
        # https://cursor.com/docs/cli/reference/configuration#required-fields
        inherit (config.cursor-agent) editor;
        version = 1;
        permissions.allow =
          # Grant read access to rig documentation and config
          [
            "Read(${manifestPath})" # The RIG.md manifest file
            "Read(${rig.docRoot}/**)" # All documentation files
            "Read(${rig.configRoot}/**)" # All config files
            "Read(${rig.toolRoot}/**)" # Tool files (for inspecting share/, lib/, etc.)
          ]
          ++ map (cmd: "Shell(${cmd})") rig.allExeNames; # Allow executing all rig tools
        permissions.deny = [ ];
      };
    in
    # Return a folder derivation with bin/ subfolder
    pkgs.writeShellScriptBin "cursor-agent" ''
      export PATH="${rig.toolRoot}/bin:$PATH"
      export RIG_DOCS="${rig.docRoot}"
      export RIG_MANIFEST="${manifestPath}"

      # cursor-agent will try to overwrite the config, so we need to copy it in a writeable temp directory
      export CURSOR_CONFIG_DIR="$(mktemp -t "${rig.name}-cursor-config-XXXXXXXXXXX" -d)"
      cp "${cliConfigJson}" "$CURSOR_CONFIG_DIR/cli-config.json"

      warn() {
        printf "\033[0;33m%s\n\033[0m" "$1" >&2
      }

      warn "NOTE: cursor-agent doesn't support startup hooks, first instruct your agent to read \$RIG_MANIFEST"

      ${pkgs.lib.getExe cursor-agent} "$@"

      rm -rf "$CURSOR_CONFIG_DIR"
    '';

  config.riglets.cursor-agent = {
    meta = {
      description = "Provides entrypoint to launch Cursor Agent with rig context";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
