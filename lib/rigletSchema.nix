# rigup flake's self
_flake:
# Base module that defines common riglet structure
{ pkgs, ... }:
with pkgs.lib;
let
  packageLike = types.oneOf [
    types.package
    types.path
  ];
  packageList = types.listOf packageLike;
in
{
  options = {
    riglets = mkOption {
      description = "Available riglets";
      type = types.attrsOf (
        types.submodule {
          options = {
            tools = mkOption {
              description = "List of tools this riglet provides";
              type = types.oneOf [
                packageList # If a single list is given, these tools are considered _wrapped_
                (types.submodule {
                  options = {
                    wrapped = mkOption {
                      description = "Tools that should be wrapped to use the rig's isolated XDG_CONFIG_HOME";
                      type = packageList;
                      default = [ ];
                    };
                    unwrapped = mkOption {
                      description = "Tools that must directly use the user's XDG_CONFIG_HOME";
                      type = packageList;
                      default = [ ];
                    };
                  };
                })
              ];
              default = [ ];
            };

            docs = mkOption {
              description = "Documentation derivation or path (folder)";
              type = types.nullOr packageLike;
              default = null;
            };

            configFiles = mkOption {
              description = "Configuration files folder. All rig's configFiles will be joined together to form the rig's XDG_CONFIG_HOME which _wrapped_ tools will then use";
              type = types.nullOr packageLike;
              default = null;
            };

            mcpServers = mkOption {
              description = "MCP (Model Context Protocol) servers this riglet provides";
              type = types.attrsOf (
                types.submodule {
                  options = {
                    command = mkOption {
                      description = "Package that starts the MCP server (stdio transport only). Nullable for remote servers (sse/http).";
                      type = types.nullOr types.package;
                      default = null;
                    };
                    transport = mkOption {
                      description = "Transport type for MCP communication";
                      type = types.enum [
                        "stdio"
                        "sse"
                        "http"
                      ];
                      default = "stdio";
                    };
                    url = mkOption {
                      description = "URL for remote MCP servers (sse/http transport)";
                      type = types.nullOr types.str;
                      default = null;
                    };
                    headers = mkOption {
                      description = "HTTP headers for remote MCP servers (e.g., for authentication)";
                      type = types.attrsOf types.str;
                      default = { };
                    };
                  };
                }
              );
              default = { };
            };

            meta = mkOption {
              description = "Metadata describing when and how to use this riglet";
              type = types.submodule {
                options = {
                  mainDocFile = mkOption {
                    description = "Path to the docs' main file (e.g. \"SKILL.md\", \"./files/index.md\"...), relative to 'docs' root";
                    type = types.pathWith {
                      absolute = false;
                    };
                    default = "SKILL.md";
                  };

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
                    # IMPORTANT: Most riglets should stick to this default, and leave it to
                    # end users to override it when building their rig.
                    # IF you choose to change this when defining a riglet,
                    # better wrap the value with `nixpkgs.lib.mkDefault` so end users
                    # may still easily override it.
                  };

                  whenToUse = mkOption {
                    description = "Situations when this riglet should be (at least partially) consulted. Empty list means IMMEDIATELY at startup";
                    type = types.listOf types.singleLineStr;
                    default = [ ];
                  };

                  keywords = mkOption {
                    description = "Keywords for searching/filtering riglets";
                    type = types.listOf types.singleLineStr;
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
        Optional entrypoint for the rig. Only ONE riglet in a rig should define this.
        Takes the rig attrset and should return a folder derivation with a SINGLE bin/xxx executable (e.g. via pkgs.writeShellScriptBin).
      '';
      type = types.nullOr (types.functionTo packageLike);
      default = null;
    };
  };
}
