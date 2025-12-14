# Base module that defines common riglet structure
{ config, pkgs, ... }:
let
  lib = pkgs.lib;
in
{
  options = {
    riglets = lib.mkOption {
      description = "Available riglets";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            tools = lib.mkOption {
              description = "List of tools this riglet provides";
              type = lib.types.listOf lib.types.package;
              default = [ ];
            };

            docs = lib.mkOption {
              description = "Documentation derivation for this riglet";
              type = lib.types.package;
            };

            config-files = lib.mkOption {
              description = "Configuration files derivation (use riglib.writeFileTree)";
              default = null;
              type = lib.types.nullOr lib.types.package;
            };

            meta = lib.mkOption {
              description = "Metadata describing when and how to use this riglet";
              type = lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Human-readable riglet name";
                  };

                  description = lib.mkOption {
                    type = lib.types.str;
                    description = "Brief description of what this riglet provides";
                  };

                  whenToUse = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Situations when this riglet should be loaded";
                  };

                  keywords = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Keywords for searching/filtering riglets";
                  };

                  status = lib.mkOption {
                    type = lib.types.enum [
                      "stable"
                      "experimental"
                      "draft"
                      "deprecated"
                      "example"
                    ];
                    default = "experimental";
                    description = "Maturity/stability status of this riglet";
                  };

                  version = lib.mkOption {
                    type = lib.types.strMatching "^[0-9]+\\.[0-9]+\\.[0-9]+.*$";
                    default = "0.1.0";
                    description = "Semantic version of this riglet's interface/capabilities (semver format)";
                  };
                };
              };
            };
          };
        }
      );
      default = { };
    };
  };
}
