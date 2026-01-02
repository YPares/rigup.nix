self:
{ pkgs, ... }:
let
  plugin = self.inputs.anthropics-skills.claudePlugins.example-skills;
  skill = plugin.skills.frontend-design;
in
{
  # Reuse frontend-design skill from Anthropic's skills repository,
  config.riglets.frontend-design = {
    tools = [ pkgs.nodejs ];
    docs = skill.source;
    meta = {
      intent = "cookbook";
      # Nix having no "builtins.fromYAML" function, for now we use the full YAML
      # frontmatter of the SKILL.md as a description
      description = skill.rawFrontmatter;
      keywords =
        plugin.keywords or [
          "frontend"
          "design"
          "web"
          "react"
        ];
    };
  };
}
