# MCP Claude Context Server - Milvus-based context management
# Requires: MILVUS_TOKEN, optionally EMBEDDING_PROVIDER and OLLAMA_MODEL
_:
{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.mcp-claude-context = with lib.types; {
    milvusTokenEnvVar = lib.mkOption {
      type = str;
      description = "Milvus token env var";
      default = "MILVUS_TOKEN";
    };

    embeddingProvider = lib.mkOption {
      type = str;
      description = "Which embedding provider to use";
      default = "Ollama";
    };

    ollamaModel = lib.mkOption {
      type = nullOr str;
      description = "When using Ollama as embedding provider, which model to use";
      default = "embeddinggemma";
    };
  };

  config.riglets.mcp-claude-context = {
    mcpServers.claude-context = {
      command =
        with config.mcp-claude-context;
        pkgs.writeShellApplication {
          name = "mcp-claude-context";
          runtimeInputs = [ pkgs.nodejs ];
          text =
            ''export MILVUS_TOKEN="$''
            + milvusTokenEnvVar
            + ''"''
            + ''

              export EMBEDDING_PROVIDER="${embeddingProvider}"
              ${optionalString (ollamaModel != null) ''
                export OLLAMA_MODEL="${ollamaModel}"
              ''}
              exec npx @zilliz/claude-context-mcp@latest "$@"
            '';
        };
    };

    meta = {
      description = "MCP Claude Context Server with Milvus vector store";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
