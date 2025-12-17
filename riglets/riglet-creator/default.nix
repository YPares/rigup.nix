# This is a port of https://github.com/anthropics/skills/tree/main/skills/skill-creator
# to the Agent rig system
self:
{
  riglib,
  ...
}:
{
  # Use self.riglets.* for inter-riglet imports to ensure proper deduplication
  imports = [ self.riglets.agent-rig ];

  config.riglets.riglet-creator = {
    meta = {
      name = "Riglet Creator";
      description = "Guide for creating effective riglets. Use when creating new riglets or improving existing ones, defining riglet structure, metadata, documentation patterns, or integrating tools with Nix.";
      intent = "playbook";
      whenToUse = [
        "Creating new riglets"
        "Improving existing riglets"
        "Porting Skills to riglets"
        "Setting up riglet documentation"
        "Structuring riglet metadata"
        "Bundling tools with riglets"
      ];
      keywords = [
        "riglet"
        "rigup"
        "creation"
        "nix"
        "modules"
        "documentation"
        "skills"
      ];
      status = "experimental";
      version = "0.1.0";
    };

    docs = riglib.writeFileTree {
      "SKILL.md" = ./SKILL.md;
      references = {
        "patterns.md" = ./references/patterns.md;
        "metadata-guide.md" = ./references/metadata-guide.md;
      };
    };
  };
}
