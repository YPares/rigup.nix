# Base module that defines common riglet structure
{ pkgs, ... }:
with pkgs.lib;
{
  options = {
    riglets = mkOption {
      description = "Available riglets";
      type = types.attrsOf (
        types.submodule {
          options = {
            tools = mkOption {
              description = "List of tools this riglet provides";
              type = types.listOf types.package;
              default = [ ];
            };

            docs = mkOption {
              description = "Documentation derivation for this riglet";
              type = types.package;
            };

            config-files = mkOption {
              description = "Configuration files derivation (use rigwriteFileTree)";
              default = null;
              type = types.nullOr types.package;
            };

            meta = mkOption {
              description = "Metadata describing when and how to use this riglet";
              type = types.submodule {
                options = {
                  name = mkOption {
                    type = types.str;
                    description = "Human-readable riglet name";
                  };

                  description = mkOption {
                    type = types.str;
                    description = "Brief description of what this riglet provides";
                  };

                  whenToUse = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "Situations when this riglet should be loaded";
                  };

                  keywords = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "Keywords for searching/filtering riglets";
                  };

                  status = mkOption {
                    type = types.enum [
                      "stable"
                      "experimental"
                      "draft"
                      "deprecated"
                      "example"
                    ];
                    default = "experimental";
                    description = "Maturity/stability status of this riglet";
                  };

                  version = mkOption {
                    type = types.strMatching "^[0-9]+\\.[0-9]+\\.[0-9]+.*$";
                    default = "0.1.0";
                    description = "Semantic version of this riglet's interface/capabilities (semver format)";
                  };

                  broken = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Whether this riglet is currently broken/non-functional and needs fixing";
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
