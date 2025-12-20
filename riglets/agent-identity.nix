_:
{
  lib,
  ...
}:
{
  # Define shared options at top level
  options.agent.identity = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "AI-Agent";
      description = "AI Agent's username (e.g. for version control and documentation)";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "foo@bar.qux";
      description = "AI Agent's email address (can be fake)";
    };
  };

  config.riglets.agent-identity = {
    meta = {
      description = "Give an identity to the agent, to be reused by other riglets that need config like name and email";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
