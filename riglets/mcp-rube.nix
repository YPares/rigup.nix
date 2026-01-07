_:
{ ... }:
{
  config.riglets.mcp-rube = {
    mcpServers.rube = {
      transport = "http";
      url = "https://rube.app/mcp";
    };

    meta = {
      description = "Rube MCP server";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
