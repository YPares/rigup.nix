_:
{ lib, ... }:
{
  options.lspServers =
    with lib;
    mkOption {
      description = "LSP servers to be used by the agent";
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            disabled = mkOption {
              type = types.bool;
              description = "Disable this LSP";
              default = false;
            };
            command = mkOption {
              type = types.nullOr types.package;
              description = "Which package to run. 'null' to use default config for this LSP";
              default = null;
            };
            extensions = mkOption {
              type = types.nullOr (types.listOf types.str);
              description = "Which file extensions to use this LSP server with (including '.' prefixes). 'null' to use default config for this LSP";
              default = null;
            };
            initialization = mkOption {
              type = types.nullOr (types.attrsOf types.anything);
              description = "Initialization options to send to the LSP server";
              default = null;
            };
          };
        }
      );
    };

  config.riglets.lsp-servers.meta = {
    description = "LSP servers to enable (to be imported by compatible entrypoints)";
    status = "experimental";
    version = "0.1.0";
    intent = "base";
    disclosure = "none";
  };
}
