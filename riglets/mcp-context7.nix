# MCP Context7 Server - documentation context (HTTP)
# Requires: CONTEXT7_API_KEY environment variable
_:
{ config, lib, ... }:
{
  options.mcp-context7.apiKeyEnVar = lib.mkOption {
    type = lib.types.str;
    description = "Context7 API key env var";
    default = "CONTEXT7_API_KEY";
  };

  config.riglets.mcp-context7 = {
    mcpServers.context7 = {
      transport = "http";
      url = "https://mcp.context7.com/mcp";
      headers.CONTEXT7_API_KEY = "$" + config.mcp-context7.apiKeyEnvVar;
    };

    meta = {
      description = "MCP Context7 Server for documentation context";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
