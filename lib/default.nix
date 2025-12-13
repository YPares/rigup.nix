{ ... }:
{
  # Evaluate a rig from a set of riglet modules
  # Returns an attrset with:
  #   - env: combined buildEnv of all tools
  #   - docs: attrset of riglet name -> docs derivation
  buildRig =
    {
      modules,
      pkgs,
      name ? "agent-rig",
    }:
    let
      lib = pkgs.lib;

      # Evaluate the module system with all riglet modules
      evaluated = lib.evalModules {
        modules = modules ++ [
          ./rigletSchema.nix
        ];
        # Pass pkgs to all modules
        specialArgs = { inherit pkgs; };
      };
    in
    {
      # Combined tools from all riglets
      env = pkgs.buildEnv {
        inherit name;
        paths = lib.flatten (lib.mapAttrsToList (_: riglet: riglet.tools) evaluated.config.riglets);
      };

      # Docs per riglet
      docs = lib.mapAttrs (_: riglet: riglet.docs) evaluated.config.riglets;
    };
}
