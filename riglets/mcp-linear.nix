# MCP Linear Server - Linear issue tracker integration (HTTP)
_:
{ ... }:
{
  config.mcpServers.linear = {
    transport = "http";
    url = "https://mcp.linear.app/mcp";
  };

  config.riglets.mcp-linear.meta = {
    description = "Linear MCP Server (HTTP)";
    intent = "base";
    disclosure = "none";
    status = "experimental";
    version = "0.1.0";
  };
}
