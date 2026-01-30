_:
{ config, lib, ... }:
{
  options.mcp-figma.url = lib.mkOption {
    type = lib.types.str;
    description = "HTTP url of the remote MCP server";
    default = "https://mcp.figma.com/mcp";
  };
  
  config.riglets.mcp-figma = {
    mcpServers.figma = {
      transport = "http";
      url = config.mcp-figma.url;
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
