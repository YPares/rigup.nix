_:
{ ... }:
{
  config.riglets.mcp-figma = {
    mcpServers.figma = {
      transport = "http";
      url = "https://mcp.figma.com/mcp";
    };

    meta = {
      description = "Figma MCP server";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
