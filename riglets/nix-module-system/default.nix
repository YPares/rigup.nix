# Dark corners of the Nix module system (lib.evalModules)
_:
{
  riglib,
  ...
}:
{
  config.riglets.nix-module-system = {
    meta = {
      description = "Practical knowledge about lib.evalModules that's hard to find in official docs — deduplication, priority, debugging";
      intent = "sourcebook";
      whenToUse = [
        "Debugging 'option defined multiple times' errors"
        "Debugging 'infinite recursion' errors"
        "Working with module identity and deduplication"
        "Understanding mkDefault/mkForce/mkOverride priority"
        "Using _module.args vs specialArgs"
        "Writing modules that integrate with NixOS/home-manager"
      ];
      keywords = [
        "nix"
        "modules"
        "evalModules"
        "mkDefault"
        "mkForce"
        "mkIf"
        "mkMerge"
        "infinite recursion"
        "deduplication"
        "key"
        "specialArgs"
        "_module.args"
      ];
      status = "experimental";
      version = "0.1.0";
    };

    docs = riglib.writeFileTree {
      "SKILL.md" = ./SKILL.md;
      references = {
        "troubleshooting.md" = ./references/troubleshooting.md;
      };
    };
  };
}
