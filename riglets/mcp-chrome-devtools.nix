_:
{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.mcp-chrome-devtools.browserUrl = lib.mkOption {
    description = "Chrome browser URL to connect to";
    type = lib.types.singleLineStr;
  };

  config.mcpServers.chrome-devtools.command = pkgs.writeShellApplication {
    name = "mcp-chrome-devtools";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec npx -y chrome-devtools-mcp@latest \
        --browser-url=${config.mcp-chrome-devtools.browserUrl}
    '';
  };

  config.riglets.mcp-chrome-devtools.meta = {
    description = "MCP server for chrome-devtools";
    intent = "base";
    disclosure = "none";
    status = "experimental";
    version = "0.1.0";
  };
}
