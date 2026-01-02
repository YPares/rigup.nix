self:
{ pkgs, ... }:
let
  plugin = self.inputs.anthropics-skills.claudePlugins.example-skills;
  skill = plugin.skills.algorithmic-art;
in
{
  # Reuse algorithmic-art skill from Anthropic's skills repository
  config.riglets.algorithmic-art = {
    tools = [ pkgs.nodejs ];
    docs = skill.source;
    meta = {
      intent = "sourcebook";
      # Nix having no "builtins.fromYAML" function, for now we use the full YAML
      # frontmatter of the SKILL.md as a description
      description = skill.rawFrontmatter;
      keywords =
        plugin.keywords or [
          "art"
          "p5.js"
        ];
    };
  };
}
