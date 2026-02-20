# rigup flake's self
flake:
# Base module that defines common riglet structure
{ pkgs, lib, ... }:
with lib.types;
let
  inherit (lib) mkOption;

  riglib = flake.lib.mkRiglib { inherit pkgs; };

  # An actual Nix path object
  actualPath = addCheck (pathWith { }) builtins.isPath;

  # Anything that can become a folder in store
  folder = addCheck (either actualPath pathInStore) lib.pathIsDirectory;

  # A package or a single shell script file _without_ dependencies outside of pkgs.stdenv
  executable = coercedTo (addCheck actualPath lib.pathIsRegularFile) riglib.wrapScriptPath package;

  # A set of tools to be exposed to an agent using a riglet, with extra info about how
  # to wrap them with environment variables
  toolset =
    coercedTo
      # If just a list of packages is given as a toolset, these tools are considered _wrapped_:
      (listOf executable)
      (x: { wrapped = x; })
      # Else, for more explicit control over which tools should be wrapped and which should not,
      # the toolset can be given as a { wrapped = [...]; unwrapped [...]; } attrset:
      (
        submodule {
          options = {
            wrapped = mkOption {
              description = "Tools that should be wrapped to use the rig's isolated XDG_CONFIG_HOME";
              type = listOf executable;
              default = [ ];
            };
            unwrapped = mkOption {
              description = "Tools that must directly use the user's XDG_CONFIG_HOME";
              type = listOf executable;
              default = [ ];
            };
          };
        }
      );

  localMcpServer = submodule {
    options.command = mkOption {
      description = "Single-exe package that starts a local MCP server (stdio transport)";
      type = package;
    };
  };

  remoteMcpServer = submodule {
    options = {
      url = mkOption {
        description = "URL for remote MCP server (SSE/HTTP transport)";
        type = str;
      };
      useSSE = mkOption {
        description = "Use Server-Side Events instead of plain HTTP";
        type = bool;
        default = false;
      };
      headers = mkOption {
        description = "HTTP headers for remote MCP server";
        type = attrsOf str;
        default = { };
      };
    };
  };

  mcpServer = oneOf [
    (addCheck localMcpServer (x: x ? command))
    (addCheck remoteMcpServer (x: x ? url))
  ];

  promptCommand = submodule {
    options = {
      template = mkOption {
        description = "The command template itself. Can use $ARGUMENTS, $1, $2...";
        type = str;
      };

      description = mkOption {
        description = "Short explanation of what this prompt command does. Usually shown in help or autocompletion menu in the harness";
        type = str;
      };

      readDocsFirst = mkOption {
        description = "Add an instruction to read the riglet's doc first (if it is not eagerly disclosed and contains docs)";
        type = bool;
        default = true;
      };

      useSubAgent = mkOption {
        description = "Have a sub-agent read and run the command (`context: fork` in Claude Code, `subtask: true` in OpenCode). Support depends on harness";
        type = bool;
        default = false;
      };
    };
  };
in
{
  options = {
    riglets = mkOption {
      description = "Available riglets";
      type = attrsOf (submodule {
        options = {
          tools = mkOption {
            description = "Tools that this riglet provides";
            type = toolset;
            default = [ ];
          };

          docs = mkOption {
            description = "Documentation folder";
            type = nullOr folder;
            default = null;
          };

          configFiles = mkOption {
            description = "Configuration files folder. All rig's configFiles will be joined together to form the rig's XDG_CONFIG_HOME which _wrapped_ tools will then use";
            type = nullOr folder;
            default = null;
          };

          # Currently, deny rules are scoped per riglet.
          # WARNING: STILL EXPERIMENTAL. Schema for custom rules is subject to change
          denyRules = mkOption {
            description = ''
              Command deny rules for harness entrypoints, structured by tool name.
              Each tool can have a list of command patterns to deny.
              Example: { git = ["push" "pull"]; jj = ["git push"]; }
              These rules complement the blanket allow rules that entrypoints generate for all rig tools.
            '';
            type = attrsOf (listOf str);
            default = { };
          };

          # promptCommands all have a name, but to allow two commands with the same name to coexist in the rig (and possibly with other commands from user's or project's config), buildRig will prefix them by the riglet's name.
          # This is why promptCommands are scoped per riglet.
          # WARNING: STILL EXPERIMENTAL. Schema for promptCommands is subject to change
          promptCommands = mkOption {
            description = ''
              Reusable prompt templates ("slash commands" for Claude Code, or simply "commands" for OpenCode)
            '';
            type = attrsOf promptCommand;
            default = { };
          };

          meta = mkOption {
            description = "Metadata describing when and how to use this riglet";
            type = submodule {
              options = {
                mainDocFile = mkOption {
                  description = ''
                    Path to the docs' main file (e.g. "SKILL.md", "./files/index.md"...), relative to 'docs' root
                  '';
                  type = pathWith {
                    absolute = false;
                  };
                  default = "SKILL.md";
                };

                description = mkOption {
                  description = "Brief description of what this riglet provides";
                  type = str;
                };

                intent = mkOption {
                  description = "Type of documentation that the riglet provides";
                  type = enum [
                    "base" # Only to serve as a base for imports, e.g. to expose config options to be reused
                    "sourcebook" # Specialized facts/knowledge/context
                    "toolbox" # Open-ended collections of tools/resources
                    "cookbook" # Set of techniques, patterns, arcane tricks
                    "playbook" # Behavioural instructions and triggers, step-by-step procedures to follow
                  ];
                };

                disclosure = mkOption {
                  description = "How to disclose this riglet's via the RIG.md manifest";
                  type = enum [
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
                  description = ''
                    Situations when this riglet should be (at least partially) consulted.
                    Empty list means IMMEDIATELY at startup
                  '';
                  type = listOf singleLineStr;
                  default = [ ];
                };

                keywords = mkOption {
                  description = "Keywords for searching/filtering riglets";
                  type = listOf singleLineStr;
                  default = [ ];
                };

                status = mkOption {
                  description = "Maturity/stability status of this riglet";
                  type = enum [
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
                  type = strMatching "^[0-9]+\\.[0-9]+\\.[0-9]+.*$";
                  default = "0.1.0";
                };

                broken = mkOption {
                  description = "Whether this riglet is currently broken/non-functional and needs fixing";
                  type = bool;
                  default = false;
                };
              };
            };
          };
        };
      });
      default = { };
    };

    # entrypoint is not scoped per riglet, as only one should exist for the entire rig
    entrypoint = mkOption {
      description = ''
        Optional entrypoint for the rig. Only ONE riglet in a rig should define this.
        Takes the rig attrset and should return a folder derivation with a SINGLE bin/xxx executable (e.g. via pkgs.writeShellScriptBin).
      '';
      type = nullOr (functionTo package);
      default = null;
    };

    # mcpServers are already scoped by name, and conversely to commands it would make little sense to have two mcpServers named the same in the rig (plus, harnesses would not support this).
    # So mcpServers are not scoped per riglet.
    # Also, this permits to add simple MCP configs (e.g. that requires only 'transport' & 'url') directly in rigup.toml.
    # WARNING: STILL EXPERIMENTAL. Schema for mcpServers is subject to change
    mcpServers = mkOption {
      description = "Configuration for MCP (Model Context Protocol) servers";
      type = attrsOf mcpServer;
      default = { };
    };
  };
}
