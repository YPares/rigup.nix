# MCP Tmux Server - terminal multiplexer integration
_:
{ pkgs, ... }:
{
  config.riglets.mcp-tmux = {
    mcpServers.tmux = {
      command = pkgs.writeShellApplication {
        name = "mcp-tmux";
        runtimeInputs = [ pkgs.nodejs ];
        text = ''
          exec npx -y tmux-mcp "$@"
        '';
      };
    };

    meta = {
      description = "MCP Tmux Server for terminal multiplexer control";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
