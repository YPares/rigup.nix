# MCP Tmux Server - terminal multiplexer integration
_:
{ pkgs, ... }:
{
  config.mcpServers.tmux.command = pkgs.writeShellApplication {
    name = "mcp-tmux";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec npx -y tmux-mcp "$@"
    '';
  };

  config.riglets.mcp-tmux.meta = {
    description = "Tmux MCP server";
    intent = "base";
    disclosure = "none";
    status = "experimental";
    version = "0.1.0";
  };
}
