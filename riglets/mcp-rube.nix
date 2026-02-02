_:
{ ... }:
{
  config.mcpServers.rube = {
    transport = "http";
    url = "https://rube.app/mcp";
  };

  config.riglets.mcp-rube.meta = {
    description = "Rube MCP server (HTTP)";
    intent = "base";
    disclosure = "none";
    status = "experimental";
    version = "0.1.0";
  };
}
