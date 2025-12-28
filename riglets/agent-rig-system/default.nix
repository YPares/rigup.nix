self:
{
  riglib,
  system,
  pkgs,
  ...
}:
{
  config.riglets.agent-rig-system = {
    tools = with pkgs; [
      self.packages.${system}.extract-md-toc
      tree
      ripgrep
    ];

    meta = {
      description = "rigup.nix: Understanding and working with riglets and rig system";
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
      status = "experimental";
      version = "0.1.0";
      disclosure = "deep-toc";
    };

    docs = riglib.writeFileTree {
      "SKILL.md" =
        with builtins;
        replaceStrings [ "lib/rigletSchema.nix" ] [ "${../../lib/rigletSchema.nix}" ] (readFile ./SKILL.md);
      references = ./references;
    };
  };
}
