# This is a port of https://github.com/anthropics/skills/tree/main/skills/skill-creator
# to the Agent rig system
self:
{
  riglib,
  ...
}:
{
  # Use self.riglets.* for inter-riglet imports to ensure proper deduplication
  imports = [ self.riglets.agent-rig-system ];

  config.riglets.riglet-creator = {
    meta = {
      description = "rigup.nix: Guide for creating effective riglets";
      intent = "playbook";
      whenToUse = [
        "Creating new riglets"
        "Porting Skills to riglets"
        "Adding to existing riglets"
        "Setting up riglet documentation or configuration"
        "Structuring riglet metadata"
        "Bundling tools with riglets"
      ];
      keywords = [
        "riglets"
        "rig"
        "rigup"
        "nix"
        "modules"
        "documentation"
        "creation"
        "skills"
      ];
      status = "stable";
      version = "0.1.0";
    };

    docs = riglib.writeFileTree {
      "SKILL.md" = ./SKILL.md;
      references = ./references;
    };
  };
}
