{
  config,
  pkgs,
  ...
}:
{
  config.riglets.agent-rig = {
    tools = [ ];

    docs = pkgs.writeTextDir "SKILL.md" ''
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
      A project's flake.nix that declares which riglets are active:
      - Uses `buildRig` to compose riglet modules
      - Builds combined tool environment declaratively
      - Exposes riglet documentation

      ### rigup
      Nix library and CLI tool:
      - `buildRig` function evaluates riglet modules with `lib/rigletSchema.nix` base
      - Returns `{ env = ...; docs = { <riglet> = ...; }; }`
      - CLI provides convenient access to rig outputs (future)

      ## Riglet Structure

      Riglets are Nix modules:

      ```nix
      { config, pkgs, lib, ... }: {
        # Riglet-specific options (optional)
        options.myRiglet = {
          myOption = lib.mkOption {
            type = lib.types.str;
            description = "Example option";
          };
        };

        # Riglet definition
        config.riglets.my-riglet = {
          tools = [ pkgs.tool1 pkgs.tool2 ];
          docs = pkgs.writeTextDir "SKILL.md" "...";
        };
      }
      ```

      ## Cross-Riglet Interaction

      Riglets can reference each other's options via `config`:

      ```nix
      # jj-basics defines agent.user.name
      options.agent.user.name = lib.mkOption { ... };

      # typst-reporter uses it
      config.riglets.typst-reporter.docs =
        # ... template using config.agent.user.name
      ```

      ## Defining Rigs in Projects

      In your project's flake.nix:

      ```nix
      {
        inputs.rigup.url = "github:YPares/rigup.nix";

        outputs = { rigup, nixpkgs, ... }:
          let
            system = "x86_64-linux";
            pkgs = import nixpkgs { inherit system; };
          in rec {
            # Rigs are exposed directly as an output so the future `rigup` CLI can use them
            rigs.$${system}.default = rigup.lib.buildRig {
              name = "my-project-rig";  # optional, defaults to "agent-rig"
              inherit pkgs;
              modules = [
                rigup.riglets.jj-basics
                rigup.riglets.typst-reporter
                {
                  agent.user.name = "Alice";
                  agent.user.email = "alice@fake.com";
                  typst.template = "academic";
                }
              ];
            };
            # Export combined tools as default package
            packages.$${system}.default = rigs.$${system}.default.env;
            # Access docs: rigs.<system>.default.docs.<riglet-name>
          };
      }
      ```

      ## Using a Rig

      **Access the combined tools:**
      ```bash
      # Build and enter shell with all rig tools
      nix develop .#rigs.<system>.default.env

      # Or build the env directly
      nix build .#rigs.<system>.default.env
      ```

      **Read riglet documentation:**
      ```bash
      # View specific riglet docs
      nix build .#rigs.<system>.default.docs.jj-basics --no-link --print-out-paths | xargs -I {} cat {}/SKILL.md

      # Or use future rigup CLI (when implemented)
      rigup docs jj-basics
      ```

      ## Creating New Riglets

      1. Create `riglets/my-riglet.nix`
      2. Define options and config as modules
      3. Add to flake's riglets output
      4. Use them in your flake's `rigs.<rig-name>` outputs

      ## Design Principles

      - **Knowledge-first**: Docs are the payload, tools are dependencies
      - **Declarative**: Configuration via Nix module options
      - **Composable**: Riglets build on each other
      - **Reproducible**: Nix ensures consistent tool versions
    '';
  };
}
