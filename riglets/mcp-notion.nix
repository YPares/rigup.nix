# MCP Notion Server - Notion workspace integration (HTTP)
_:
{ ... }:
{
  config.riglets.mcp-notion = {
    mcpServers.notion = {
      transport = "http";
      url = "https://mcp.notion.com/mcp";
    };

    meta = {
      description = "MCP Notion Server for workspace integration";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
