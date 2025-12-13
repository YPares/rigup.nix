{
  config,
  pkgs,
  ...
}:
{
  config.riglets.agent-rig = {
    tools = [ ];

    meta = {
      name = "Agent Rig System";
      description = "Understanding and working with rigup's riglet system";
      whenToUse = [
        "Learning about the rig architecture"
        "Creating new riglets"
        "Understanding how riglets interact"
        "Setting up a project's rig"
      ];
      keywords = [
        "rigup"
        "riglets"
        "rig"
        "meta"
        "architecture"
        "nix"
        "modules"
      ];
    };

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
      - Returns `{ env = ...; docs = { <riglet> = ...; }; home = ...; }`
      - CLI provides convenient access to rig outputs (future)

      **buildRig outputs:**
      - `env` - Combined tools as buildEnv (bin/, share/, etc.)
      - `docs.<riglet>` - Per-riglet documentation derivations
      - `meta.<riglet>` - Per-riglet metadata (structured discovery info)
      - `home` - Complete agent directory: RIG.md + bin/ + docs/<riglet>/

      ## Riglet Structure

      Riglets are Nix modules with access to `riglib` helpers:

      ```nix
      { config, pkgs, lib, riglib, ... }: {
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

          # Metadata for discovery and context
          meta = {
            name = "My Riglet";
            description = "What this riglet provides";
            whenToUse = [
              "Situation 1"
              "Situation 2"
            ];
            keywords = [ "keyword1" "keyword2" ];
          };

          # Simple single-file docs
          docs = riglib.writeDocsTree {
            files.SKILL = "...";
          };

          # Or nested structure (Skills pattern: SKILL.md + references/*)
          docs = riglib.writeDocsTree {
            files = {
              SKILL = "...";
              references.advanced = "...";
              references.troubleshooting = "...";
            };
          };
        };
      }
      ```

      **Metadata structure:**
      - `name` - Human-readable riglet name
      - `description` - Brief summary of what it provides
      - `whenToUse` - List of situations when this riglet is relevant
      - `keywords` - Search/filter terms

      **riglib.writeDocsTree** converts nested attrsets to directory trees:
      - `files.SKILL` → `SKILL.md`
      - `files.references.foo` → `references/foo.md`
      - Extension defaults to `.md`, customizable via `ext` parameter
      - `pkgs` is automatically available (no need to pass it)

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
            # Or export complete home as default:
            # packages.$${system}.default = rigs.$${system}.default.home;

            # Available outputs:
            # - rigs.<system>.default.env - Tools only
            # - rigs.<system>.default.docs.<riglet> - Per-riglet docs
            # - rigs.<system>.default.home - Complete environment (bin/ + docs/)
          };
      }
      ```

      ## Using a Rig

      **Complete agent environment (recommended):**
      ```bash
      # Build complete home directory with tools + docs
      nix build .#rigs.<system>.default.home

      # First, read the riglets manifest to see what's available
      cat ./result/RIG.md

      # Use the tools
      ./result/bin/jj --version

      # Read documentation (paths shown in RIG.md)
      cat ./result/docs/jj-basics/SKILL.md
      ls ./result/docs/

      # Add to PATH
      export PATH="$(nix build .#rigs.<system>.default.home --no-link --print-out-paths)/bin:$PATH"
      ```

      **RIG.md manifest:**
      The home directory includes a `RIG.md` file that lists all available riglets with:
      - Human-readable name and description
      - When to use each riglet
      - Keywords for searching
      - Documentation paths

      Agents should read this file first to understand available capabilities.

      **Access tools only:**
      ```bash
      # Build and enter shell with all rig tools
      nix develop .#rigs.<system>.default.env

      # Or build the env directly
      nix build .#rigs.<system>.default.env
      ```

      **Discover available riglets:**
      ```bash
      # View metadata for a specific riglet
      nix eval .#rigs.<system>.default.meta.jj-basics --json | jq

      # Search all riglet keywords (future rigup CLI will do this)
      nix eval .#rigs.<system>.default.meta --json | jq 'to_entries | map({riglet: .key, keywords: .value.keywords})'
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
