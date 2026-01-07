self:
{
  riglib,
  system,
  lib,
  ...
}:
{
  config.riglets.agent-rig-system = {
    tools = [ self.packages.${system}.extract-md-toc ];

    meta = {
      description = "rigup.nix: Understanding and working with riglets and rig system";
      intent = "sourcebook";
      whenToUse = [
        "Setting up or modifying a project's rig"
        "Learning about the Agent Rig architecture"
        "Learning what riglets are and what they add compared to Skills"
        "Learning how to read Markdown docs more efficiently with extract-md-toc"
        "Understanding how riglets interact"
        "Understanding how RIG.md manifest is put together"
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
      status = "stable";
      version = "0.1.0";
      # Using lib.mkDefault so user config can override it if needed
      disclosure = lib.mkDefault "deep-toc";
    };

    docs = riglib.writeFileTree {
      "SKILL.md" =
        with builtins;
        replaceStrings [ "lib/rigletSchema.nix" ] [ "${../../lib/rigletSchema.nix}" ] (readFile ./SKILL.md);
      references = ./references;
    };
  };
}
