{
  riglib,
  ...
}:
{
  config.riglets.agent-rig = {
    tools = [ ];

    meta = {
      name = "Agent Rig System";
      description = "Understanding and working with rigup's riglet system";
      whenToUse = [
        "Learning about the rig architecture"
        "Creating new riglets"
        "Understanding how riglets interact"
        "Setting up a project's rig"
      ];
      keywords = [
        "rigup"
        "riglets"
        "rig"
        "meta"
        "architecture"
        "nix"
        "modules"
      ];
      status = "experimental";
      version = "0.1.0";
    };

    docs = riglib.writeFileTree {
      "SKILL.md" = ./agent-rig/SKILL.md;
    };
  };
}
