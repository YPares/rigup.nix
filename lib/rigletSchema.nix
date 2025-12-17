_selfLib:
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
              type = types.listOf (
                types.oneOf [
                  types.package
                  types.path
                ]
              );
              default = [ ];
            };

            docs = mkOption {
              description = "Documentation derivation or path (folder)";
              type = types.oneOf [
                types.package
                types.path
              ];
            };

            config-files = mkOption {
              description = "Configuration files folder (XDG_CONFIG_DIR) derivation";
              default = null;
              type = types.nullOr types.package;
            };

            meta = mkOption {
              description = "Metadata describing when and how to use this riglet";
              type = types.submodule {
                options = {
                  name = mkOption {
                    description = "Human-readable riglet name";
                    type = types.str;
                  };

                  description = mkOption {
                    description = "Brief description of what this riglet provides";
                    type = types.str;
                  };

                  intent = mkOption {
                    description = "Type of documentation that the riglet provides";
                    type = types.enum [
                      "sourcebook" # Specialized facts/knowledge/context
                      "toolbox" # Open-ended collections of tools/resources
                      "cookbook" # Teaching techniques, patterns, arcane tricks
                      "playbook" # Step-by-step procedures to follow
                    ];
                  };

                  disclosure = mkOption {
                    description = "How to disclose this riglet via the RIG.toml manifest";
                    type = types.enum [
                      "none"
                      "lazy"
                      "toc"
                      "eager"
                    ];
                    default = "lazy";
                  };

                  whenToUse = mkOption {
                    description = "Situations when this riglet should be loaded";
                    type = types.listOf types.str;
                    default = [ ];
                  };

                  keywords = mkOption {
                    description = "Keywords for searching/filtering riglets";
                    type = types.listOf types.str;
                    default = [ ];
                  };

                  status = mkOption {
                    description = "Maturity/stability status of this riglet";
                    type = types.enum [
                      "stable"
                      "experimental"
                      "draft"
                      "deprecated"
                      "example"
                    ];
                    default = "experimental";
                  };

                  version = mkOption {
                    description = "Semantic version of this riglet's interface/capabilities (semver format)";
                    type = types.strMatching "^[0-9]+\\.[0-9]+\\.[0-9]+.*$";
                    default = "0.1.0";
                  };

                  broken = mkOption {
                    description = "Whether this riglet is currently broken/non-functional and needs fixing";
                    type = types.bool;
                    default = false;
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
