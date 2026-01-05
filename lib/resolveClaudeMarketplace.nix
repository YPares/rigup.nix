# rigup flake's self
flake:
# Import Claude Skills from marketplace.json repositories
#
# This module provides functions to parse marketplace.json and convert
# Skills to riglet definitions. Used by lib/resolveProject.nix to enhance
# flake inputs with claudeMarketplace attributes.
let
  inherit (flake.inputs.nixpkgs) lib;
in
rec {
  # Extract raw YAML frontmatter from a SKILL.md file (unparsed)
  # Returns null if no frontmatter exists
  #
  # There is currently no builtins or pkgs.lib "fromYAML" function,
  # so we have to hack around a bit.
  extractRawFrontmatter =
    skillPath:
    let
      skillMdPath = skillPath + "/SKILL.md";

      content = builtins.readFile skillMdPath;
      lines = lib.splitString "\n" content;

      # Check if starts with ---
      hasFrontmatter = lines != [ ] && builtins.head lines == "---";

      # Extract lines between first and second ---
      frontmatterText =
        if hasFrontmatter then
          let
            rest = builtins.tail lines;
            # Take lines until we hit the closing ---
            takeFrontmatter =
              lines:
              if lines == [ ] then
                [ ]
              else if builtins.head lines == "---" then
                [ ]
              else
                [ (builtins.head lines) ] ++ takeFrontmatter (builtins.tail lines);
            frontmatterLines = takeFrontmatter rest;
            joined = lib.concatStringsSep "\n" frontmatterLines;
          in
          # Return null if empty, otherwise the text
          if joined == "" then null else joined
        else
          null;
    in
    frontmatterText;

  # Import a single Claude Skill as a riglet definition (no overrides)
  #
  # Arguments:
  #   source: Path or derivation to skill directory (must contain SKILL.md)
  #   name: Optional skill ID override (defaults to basename of source)
  #
  # Returns: {source, rawFrontmatter}
  importClaudeSkill =
    source:
    let
      frontmatter = extractRawFrontmatter source;
    in
    {
      inherit source;
      rawFrontmatter =
        if frontmatter != null then frontmatter else "description: Skill imported from ${source}";
    };

  # Parse a Claude marketplace.json and return riglet definitions
  #
  # Arguments:
  #   input: A flake input (potentially containing .claude-plugin/marketplace.json)
  #
  # Returns: null if no marketplace.json, or { <plugin>.<skill> = { docs = <folder>; meta.description = <SKILL.md-frontmatter>; }; }
  resolveClaudeMarketplace =
    input:
    let
      marketplacePath = input + "/.claude-plugin/marketplace.json";
      hasMarketplace = builtins.pathExists marketplacePath;
    in
    if hasMarketplace then
      let
        marketplace = builtins.fromJSON (builtins.readFile marketplacePath);

        # Process a single plugin to extract all its skills
        processPlugin =
          plugin:
          let
            pluginSource = input + "/" + plugin.source;

            # Convert each skill to a partial riglet definition
            skillToRigletDef =
              skillPath:
              let
                fullPath = pluginSource + "/" + skillPath;
                importedSkill = importClaudeSkill fullPath;
              in
              {
                name = baseNameOf skillPath;
                value =
                  importedSkill
                  // lib.optionalAttrs (plugin ? "keywords") {
                    inherit (plugin) keywords;
                  };
              };
          in
          {
            # For now, we only import skills from each plugin
            skills = lib.listToAttrs (map skillToRigletDef plugin.skills);
          };
      in
      lib.listToAttrs (
        map (plugin: {
          name = plugin.name;
          value = processPlugin plugin;
        }) marketplace.plugins
      )
    else
      null;
}
