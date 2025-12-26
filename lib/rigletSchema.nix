# rigup flake's self
_flake:
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
              type = types.nullOr (
                types.oneOf [
                  types.package
                  types.path
                ]
              );
              default = null;
            };

            config-files = mkOption {
              description = "Configuration files folder derivation to place under $XDG_CONFIG_HOME";
              type = types.nullOr (
                types.oneOf [
                  types.package
                  types.path
                ]
              );
              default = null;
            };

            meta = mkOption {
              description = "Metadata describing when and how to use this riglet";
              type = types.submodule {
                options = {
                  description = mkOption {
                    description = "Brief description of what this riglet provides";
                    type = types.str;
                  };

                  intent = mkOption {
                    description = "Type of documentation that the riglet provides";
                    type = types.enum [
                      "base" # Only to serve as a base for imports, e.g. to expose config options to be reused
                      "sourcebook" # Specialized facts/knowledge/context
                      "toolbox" # Open-ended collections of tools/resources
                      "cookbook" # Set of techniques, patterns, arcane tricks
                      "playbook" # Behavioural instructions and triggers, step-by-step procedures to follow
                    ];
                  };

                  disclosure = mkOption {
                    description = "How to disclose this riglet's via the RIG.md manifest";
                    type = types.enum [
                      "none"
                      "lazy"
                      "shallow-toc"
                      "deep-toc"
                      "eager"
                    ];
                    default = "lazy";
                  };

                  whenToUse = mkOption {
                    description = "Situations when this riglet should be (at least partially) consulted. Empty list means IMMEDIATELY at startup";
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

    entrypoint = mkOption {
      description = ''
        Optional entrypoint function for the rig. Only ONE riglet in a rig should define this.
        Takes the rig attrset and returns a script derivation (e.g., from pkgs.writeShellScript).
        Used by `rigup run` to launch the rig's primary harness/interface.
      '';
      type = types.nullOr (
        types.functionTo (
          types.oneOf [
            types.package
            types.path
          ]
        )
      );
      default = null;
    };
  };
}
