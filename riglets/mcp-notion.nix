# MCP Notion Server - Notion workspace integration (HTTP)
_:
{ ... }:
{
  config.mcpServers.notion.url = "https://mcp.notion.com/mcp";

  config.riglets.mcp-notion.meta = {
    description = "Notion MCP server (HTTP)";
    intent = "base";
    disclosure = "none";
    status = "experimental";
    version = "0.1.0";
  };
}
