self:
{
  pkgs,
  system,
  ...
}:
let
  inherit (self.inputs.llm-agents.packages.${system}) copilot-cli;

  mkConfig =
    rig:
    (pkgs.formats.json { }).generate "copilot-config.json" {
      # Basic configuration for copilot-cli
      # Copilot CLI uses ~/.copilot/config.json by default
      # This can be customized based on rig needs
      trusted_folders = [ ];
    };

  mkMcpConfig =
    rig:
    (pkgs.formats.json { }).generate "copilot-mcp-config.json" {
      # MCP server configuration
      # Copilot CLI uses ~/.copilot/mcp-config.json by default
      mcpServers = { };
    };
in
{
  # Define the entrypoint for this rig - launches Copilot CLI with rig context
  config.entrypoint =
    rig:
    # Return a folder derivation with bin/ subfolder
    pkgs.writeShellScriptBin "copilot" ''
      export PATH="${rig.toolRoot}:$(dirname "$0"):$PATH"

      # Set up XDG_CONFIG_HOME for copilot config
      export XDG_CONFIG_HOME="${rig.configRoot}"

      # Set up copilot config directory
      export COPILOT_CONFIG_DIR="$XDG_CONFIG_HOME/copilot"
      mkdir -p "$COPILOT_CONFIG_DIR"

      # Link rig-specific configs
      ln -sf "${mkConfig rig}" "$COPILOT_CONFIG_DIR/config.json"
      ln -sf "${mkMcpConfig rig}" "$COPILOT_CONFIG_DIR/mcp-config.json"

      # Make rig docs available
      export RIG_DOCS="${rig.docRoot}"

      # Authentication note: Users should set GH_TOKEN or GITHUB_TOKEN
      if [ -z "$GH_TOKEN" ] && [ -z "$GITHUB_TOKEN" ]; then
        echo "Warning: No GitHub authentication token found."
        echo "Please set GH_TOKEN or GITHUB_TOKEN environment variable."
        echo "Get a token at: https://github.com/settings/tokens"
      fi

      exec ${pkgs.lib.getExe copilot-cli} "$@"
    '';

  config.riglets.copilot-cli-entrypoint = {
    meta = {
      description = "GitHub Copilot CLI integration: entrypoint to launch Copilot CLI with rig context";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
