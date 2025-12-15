{
  riglib,
  ...
}:
{
  config.riglets.agent-rig = {
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
      disclosure = "toc";
    };

    docs = riglib.writeFileTree {
      "SKILL.md" =
        with builtins;
        replaceStrings [ "%%RIGLET_SCHEMA%%" ] [ "${../../lib/rigletSchema.nix}" ] (readFile ./SKILL.md);
    };
  };
}
