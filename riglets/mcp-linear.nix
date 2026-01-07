# MCP Linear Server - Linear issue tracker integration (HTTP)
_:
{ ... }:
{
  config.riglets.mcp-linear = {
    mcpServers.linear = {
      transport = "http";
      url = "https://mcp.linear.app/mcp";
    };

    meta = {
      description = "MCP Linear Server for issue tracking";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
