# MCP Memory Server - persistent memory for AI agents
_:
{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.mcp-memory.memoryFilePath = lib.mkOption {
    type = lib.types.pathWith { inStore = false; };
    description = "Where to store the memory file";
    default = "$HOME/.mcp-memory.json";
  };

  config.mcpServers.memory.command = pkgs.writeShellApplication {
    name = "mcp-memory";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export MEMORY_FILE_PATH="${config.mcp-memory.memoryFilePath}"
      exec npx -y @modelcontextprotocol/server-memory "$@"
    '';
  };

  config.riglets.mcp-memory.meta = {
    description = "MCP server for persistent agent memory";
    intent = "base";
    disclosure = "none";
    status = "experimental";
    version = "0.1.0";
  };
}
