_:
{
  riglib,
  ...
}:
{
  config.riglets.agent-rig = {
    meta = {
      description = "Understanding and working with rigup's riglet system - REPLACED BY agent-rig-system";
      intent = "sourcebook";
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
      status = "deprecated";
      version = "0.1.0";
      disclosure = "deep-toc";
    };

    docs = riglib.writeFileTree {
      "SKILL.md" =
        with builtins;
        replaceStrings [ "lib/rigletSchema.nix" ] [ "${../../lib/rigletSchema.nix}" ] (
          readFile ../agent-rig-system/SKILL.md
        );
      references = ../agent-rig-system/references;
    };
  };
}
