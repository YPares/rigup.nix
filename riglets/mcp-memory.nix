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
    default = "/home/fake-user-xxxxx/.mcp-memory.json";
  };

  config.riglets.mcp-memory = {
    mcpServers.memory = {
      command = pkgs.writeShellApplication {
        name = "mcp-memory";
        runtimeInputs = [ pkgs.nodejs ];
        text = ''
          export MEMORY_FILE_PATH="${config.mcp-memory.memoryFilePath}"
          exec npx -y @modelcontextprotocol/server-memory "$@"
        '';
      };
    };

    meta = {
      description = "MCP Memory Server for persistent agent memory";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
