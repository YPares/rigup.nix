{ config, pkgs, lib, ... }:
{
  options.riglets.agent-rig = lib.mkOption {
    type = lib.types.submodule {
      options = {
        tools = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [];
        };

        docs = lib.mkOption {
          type = lib.types.package;
          default = pkgs.writeTextDir "SKILL.md" ''
            # Agent Rig System

            ## Overview

            A **rig** is a project-scoped collection of riglets that provide knowledge and tools for AI agents.

            ## Core Concepts

            ### Riglet
            A riglet is executable knowledge packaged with its dependencies:
            - **Knowledge**: SKILL.md documenting processes and recipes
            - **Tools**: Nix packages needed to execute those recipes
            - **Configuration**: Options that adapt behavior to project context

            ### Rig
            A project's `.rig/` directory containing:
            - `flake.nix` or `rigup.yaml` - declares which riglets are active
            - `profile/` - Nix profile with installed tools (gitignored)

            ### rigup
            CLI tool that:
            - Reads riglet declarations
            - Ensures tools are installed in isolated profile
            - Outputs riglet documentation to agents

            ## Riglet Structure

            Riglets are Nix modules:

            ```nix
            { config, pkgs, lib, ... }: {
              options.riglets.my-riglet = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    # Riglet-specific options
                    myOption = lib.mkOption {
                      type = lib.types.str;
                      description = "Example option";
                    };
                  };
                };
              };

              config.riglets.my-riglet = {
                tools = [ pkgs.tool1 pkgs.tool2 ];
                docs = pkgs.writeTextDir "SKILL.md" "...";
              };
            }
            ```

            ## Cross-Riglet Interaction

            Riglets can reference each other's options via `config`:

            ```nix
            # jj-basics defines user.name
            options.user.name = lib.mkOption { ... };

            # typst-reporter uses it
            config.riglets.typst-reporter.docs =
              # ... template using config.user.name
            ```

            ## Templating

            Use minijinja for dynamic documentation:

            ```nix
            docs = pkgs.runCommand "docs" {
              buildInputs = [ pkgs.minijinja ];
            } ''
              echo '${builtins.toJSON config}' | \
                minijinja ''${./template.md} > $out/SKILL.md
            '';
            ```

            ## Creating New Riglets

            1. Create `riglets/my-riglet.nix`
            2. Define options and config
            3. Add to flake's riglets output
            4. Test with `rigup read my-riglet`

            ## Design Principles

            - **Knowledge-first**: Docs are the payload, tools are dependencies
            - **Declarative**: Configuration via Nix module options
            - **Composable**: Riglets build on each other
            - **Reproducible**: Nix ensures consistent tool versions
          '';
        };
      };
    };
  };

  config.riglets.agent-rig = {
    # No tools needed for meta-documentation
    tools = [];
  };
}
