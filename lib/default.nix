{
  # Evaluate a rig from a set of riglet modules
  # Returns an attrset with:
  #   - tools: combined buildEnv of all tools
  #   - docs: attrset of riglet name -> docs derivation
  buildRig = { modules, pkgs, system ? pkgs.system }:
    let
      lib = pkgs.lib;
      # Evaluate the module system with all riglet modules
      evaluated = lib.evalModules {
        modules = modules ++ [
          # Base module that defines common riglet structure
          ({ config, ... }: {
            options = {
              riglets = lib.mkOption {
                type = lib.types.attrsOf (lib.types.submodule {
                  options = {
                    tools = lib.mkOption {
                      type = lib.types.listOf lib.types.package;
                      default = [];
                      description = "List of tools this riglet provides";
                    };

                    docs = lib.mkOption {
                      type = lib.types.package;
                      description = "Documentation derivation for this riglet";
                    };
                  };
                });
                default = {};
                description = "Available riglets";
              };
            };
          })
        ];

        # Pass pkgs to all modules
        specialArgs = { inherit pkgs; };
      };

      cfg = evaluated.config;
    in
    {
      # Combined tools from all riglets
      tools = pkgs.buildEnv {
        name = "rig-tools";
        paths = lib.flatten (lib.mapAttrsToList (_: riglet: riglet.tools) cfg.riglets);
      };

      # Docs per riglet
      docs = lib.mapAttrs (_: riglet: riglet.docs) cfg.riglets;
    };
}
