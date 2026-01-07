# MCP Cased Kit Server - development toolkit
_:
{ pkgs, ... }:
{
  config.riglets.mcp-cased-kit = {
    mcpServers.cased-kit = {
      command = pkgs.writeShellApplication {
        name = "mcp-cased-kit";
        runtimeInputs = [ pkgs.uv ];
        text = ''
          exec uvx --from "cased-kit>=2.0.0" kit-dev-mcp "$@"
        '';
      };
    };

    meta = {
      description = "MCP Cased Kit development toolkit";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
