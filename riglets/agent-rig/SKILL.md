# Agent Rig System

## Overview

A **rig** is a project-scoped collection of riglets that provide knowledge and tools for AI agents.

## Core Concepts

### Riglet
A riglet is executable knowledge packaged with its dependencies, as a Nix module:
- **Metadata**: When should this riglet be used, is it production-ready or experimental, etc.
- **Knowledge**: SKILL.md documenting processes and recipes
- **Tools**: Nix packages needed to execute those recipes
- **Configuration**: Settings to adapt the behavior to project context

### Rig
A project-level structure that declares which riglets are active:
- Uses `buildRig` to compose riglet modules
- Builds combined tool environment declaratively
- Exposes riglet documentation

### rigup
A Nix library and future CLI tool: http://github.com/YPares/rigup.nix

The lib contains:
- `buildRig` function: evaluates riglet modules and ensures they comply with the riglet schema used by rigup. Returns the rig as an attrset: `{ env = ...; meta = { <riglet> = ... }; docs = { <riglet> = ...; }; home = ...; }`
- `resolveProject` function: inspects the `riglets/` folder of a project and its `rigup.toml` to find out which riglets and rigs it defines. It calls `buildRig` for each rig in the `rigup.toml`

**buildRig outputs:**
- `env` - Tools combined through nixpkgs `buildEnv` function (bin/, share/, etc.)
- `meta.<riglet>` - Per-riglet metadata (discovery info structured as a Nix attrset)
- `docs.<riglet>` - Per-riglet documentation derivations
- `home` - Complete agent directory: RIG.md + bin/ + docs/ + .config/

CLI will provide convenient rig edition & access to rig outputs (e.g. starting a shell with all env vars needed set to operate the rig)

## Riglet Structure

Riglets are Nix modules with access to `riglib` helpers

### Example Riglet

```nix
# First argument: the defining flake's `self`
# Gives access to `self.inputs.*` and `self.riglets.*`
# Use `_:` if you don't need it
_:

# Second argument: module args from evalModules
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
    # Tools can be:
    # - Nix packages: pkgs.jujutsu, pkgs.git, etc.
    # - Script paths: ./scripts/my-script (auto-wrapped as executables)
    tools = [
      pkgs.tool1
      pkgs.tool2
      ./scripts/helper-script  # Becomes executable "helper-script"
    ];

    # Metadata for discovery and context
    meta = {
      name = "My Riglet"; # Human readable name
      description = "What this riglet provides";
      intent = "cookbook";  # sourcebook | toolbox | cookbook | playbook
      whenToUse = [
        "Situation 1" # When the AI Agent should use this riglet's recipes and tools
        "Situation 2"
      ];
      keywords = [ "keyword1" "keyword2" ];
      status = "experimental";  # stable | experimental (default) | draft | deprecated | example
      version = "x.y.z";  # Semantic version of riglet's interface (configuration + provided methods, procedures, docs...)
      broken = false; # Optional. false by default
      disclosure = "lazy" # How much to show about riglet in manifest. "lazy" by default
    };

    # Documentation file(s) (Skills pattern: SKILL.md + references/*.md)
    docs = riglib.writeFileTree {
      "SKILL.md" = "...";  # SKILL.md MUST BE PRESENT
      references = {       # Optional. To add deeper knowledge about more specific topics, less common recipes, etc.
                           # SKILL.md should mention when each reference becomes relevant
        "advanced.md" = "...";
        "troubleshooting.md" = "...";
      };
    };

    # Alternatively, if you already have a folder that follows this same Agent Skill layout, you can directly reuse it:
    #docs = ./path/to/skill/folder;

    # Configuration files (optional)
    config-files = riglib.writeFileTree {
      myapp."config.toml" = (pkgs.formats.toml {}).generate "myapp-config" {
        setting = "value";
      };
      # Or just plain text
      myapp."script.sh" = "#!/bin/bash\necho hello";
    };
  };
}
```

**The full exact Nix module schema of a riglet is defined here:** %%RIGLET_SCHEMA%%

### Metadata

**About meta.intent:**
Primary focus/intent of the riglet:
- `sourcebook` - Specialized facts, knowledge, terminology, or domain context for guiding thinking
- `toolbox` - Collections of tools/resources with minimal context on how they work together. Open-ended by nature
- `cookbook` - Teaching specialized techniques and patterns; arcane tricks agents may lack
- `playbook` - Step-by-step procedures for executing specific workflows

**About meta.status:**
Maturity level:
- `stable` - Production-ready, well-tested riglet
- `experimental` - Usable but may change, not fully battle-tested
- `draft` - Work in progress, incomplete
- `deprecated` - No longer maintained, use alternatives
- `example` - Pedagogical riglet for demonstrating patterns

**About meta.version:**
Semantic version (default: `"0.1.0"`) of riglet's interface/capabilities:
- Use semver format: `MAJOR.MINOR.PATCH` (e.g., `"1.2.3"`)
- Increment MAJOR for breaking changes (renamed options, removed features)
- Increment MINOR for backwards-compatible additions (new options, new docs sections)
- Increment PATCH for backwards-compatible fixes (doc corrections, bug fixes)

**About meta.broken:**
Boolean flag indicating riglet is currently non-functional:
- Like Nix derivations' `meta.broken`, marks temporary "needs fixing" state
- Takes precedence over status in warnings

**About meta.disclosure:**
Enum controlling how much information about the riglet is exposed in RIG.md
- `none` - Riglet not mentioned in RIG.md. Agent won't know it exists unless manually browsing the rig or user mentions it
- `lazy` - Description, `whenToUse`, keywords, and basic metadata included. Paths to documentation provided (default)
- `toc` - Like `lazy`, plus an auto-generated table of contents from SKILL.md with line numbers for efficient navigation
- `eager` - Full top-level SKILL.md content embedded directly in RIG.md

This controls the information/token-count ratio:
- most riglets use `lazy` to avoid overwhelming agents during discovery
- foundational riglets use `toc` to enable efficient pinpointing
- `eager` should only be used for very short SKILL.md

### Tool Config Files

**config-files** provides configuration for tools:
- Uses `riglib.writeFileTree` to create `.config/` directory structure
- Follows XDG Base Directory specification
- All riglets' config-files are merged into `.config/`
- Example: `jj."config.toml"` → `.config/jj/config.toml`
- Can use `pkgs.formats.toml`, `.json`, `.yaml` to generate config files from Nix data
- Can use plain strings for shell scripts or plain text configs


### Helper Functions to Use

**riglib.writeFileTree** converts nested attrsets to directory trees:
- Takes a single attrset argument
- `"SKILL.md"` → `SKILL.md`
- `references."foo.md"` → `references/foo.md`
- Extensions must be included in attribute names
- Leaf values can be:
  - Strings (inline content)
  - File paths (e.g., `./SKILL.md` - useful for directory-based riglets)
  - Derivations (e.g., `pkgs.writeText` or `(pkgs.formats.<format> {}).generate`)

## Cross-Riglet Interaction

### Sharing options via `config`

Riglets can reference each other's options via `config`:

```nix
# jj-basics defines agent.user.name
options.agent.user.name = lib.mkOption { ... };

# typst-reporter uses it
config.riglets.typst-reporter.docs = ''
  # ... template using config.agent.user.name
'';
```

### Inter-riglet dependencies via `imports`

If a riglet depends on another, use `imports` with `self.riglets.*`:

```nix
self:
{ riglib, ... }: {
  # Import the base riglet - evalModules deduplicates if both are in the rig
  imports = [ self.riglets.base-riglet ];

  config.riglets.advanced-riglet = { ... };
}
```

**IMPORTANT:** Always use `self.riglets.*` for imports, never path-based imports like `./base-riglet.nix`. The `self.riglets.*` form ensures proper deduplication.

For riglets from external flakes:

```nix
imports = [ self.inputs.other-flake.riglets.some-riglet ];
```

### Using external packages

Access packages from external flakes via `self.inputs`:

```nix
self:
{ pkgs, system, riglib, ... }: {
  config.riglets.my-riglet = {
    tools =
      # Use the provided system to select the right platform
      # (`system` arg == `pkgs.stdenv.hostPlatform.system` == `pkgs.system` but last one is deprecated)
      let someFlakePkgs = self.inputs.some-flake.packages.${system};
      in [
        someFlakePkgs.foo
        someFlagePkgs.bar
        pkgs.git
      ];
  };
}
```

## Defining Rigs in Projects

### Recommended: Use rigup.toml

Add a `rigup.toml` file to your project root:

```toml
[rigs.default.riglets]
self = ["my-riglet"]
rigup = ["jj-basics"]

[rigs.default.config.agent.user]
name = "Alice"
email = "alice@example.com"
```

Then use `rigup.lib.resolveProject` in your flake.nix:

```nix
{
  inputs.rigup.url = "github:YPares/rigup.nix";

  outputs = { self, rigup, ... }@inputs:
    let system = "x86_64-linux";
    in
    # Using the rigup flake directly as a function is equivalent to calling
    # `rigup.lib.resolveProject`, as `rigup` defines the __functor attr
    rigup { inherit inputs; } //
    # We can declare a few output packages to give a more direct access to the rig
    {
      # A package that exposes just the tools of the rig
      packages.${system}.default-rig-tools = self.rigs.${system}.default.env;
      # A package that exposes the home of the rig (metadata manifest + tools + docs)
      packages.${system}.default-rig = self.rigs.${system}.default.home;
    };
}
```

`resolveProject` auto-discovers riglets from `riglets/` and builds rigs from `rigup.toml`.

**`resolveProject` outputs:**
- `riglets.<riglet>` - Auto-discovered riglet modules
- `rigs.<system>.<rig>.env` - Tools only
- `rigs.<system>.<rig>.docs.<riglet>` - Per-riglet docs
- `rigs.<system>.<rig>.meta.<riglet>` - Per-riglet metadata
- `rigs.<system>.<rig>.home` - Complete environment (RIG.md + bin/ + docs/ + .config/)

### Advanced: Directly use buildRig for complex config

For config not representable in TOML:

```nix
{
  inputs.rigup.url = "github:YPares/rigup.nix";

  outputs = { self, rigup, nixpkgs, ... }@inputs:
    let
      resolved = rigup.lib.resolveProject { inherit inputs; };
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    resolved // {
      rigs.${system}.custom = rigup.lib.buildRig {
        name = "my-custom-rig";
        inherit pkgs;
        modules = [
          rigup.riglets.jj-basics
          {
            # Complex Nix expressions
            agent.complexOption = lib.mkIf condition value;
          }
        ];
      };
    };
}
```

## Using a Rig

**Via the home output of the rig (recommended):**
```bash
# Build complete home directory with tools + docs + config
nix build .#rigs.<system>.<rig>.home

# First, read the riglets manifest to see what's available
cat ./result/RIG.md

# Use the tools
./result/bin/jj --version

# Read documentation (paths shown in RIG.md)
cat ./result/docs/jj-basics/SKILL.md
ls ./result/docs/

# Use configuration files (XDG Base Directory compatible)
export XDG_CONFIG_HOME="$(nix build .#rigs.<system>.default.home --no-link --print-out-paths)/.config"

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
# !!! it's `shell` and not `develop` because we want a shell which provides the _given packages_ directly, not a shell which provides the _buildInputs_ of the given packages !!!
nix shell .#rigs.<system>.default.env

# Or build the env directly
nix build .#rigs.<system>.default.env
```

**Discover available riglets:**
```bash
# View metadata for a specific riglet
nix eval .#rigs.<system>.default.meta.<riglet> --json | jq

# Search all riglet keywords (future rigup CLI will do this)
nix eval .#rigs.<system>.default.meta --json | jq 'to_entries | map({riglet: .key, keywords: .value.keywords})'
```

**Read riglet documentation:**
```bash
# View specific riglet docs
nix build .#rigs.<system>.default.docs.<riglet> --no-link --print-out-paths | xargs -I {} cat {}/SKILL.md

# Or use future rigup CLI (when implemented)
rigup docs <riglet>
```

## Creating New Riglets

In some project:

1. Create the `riglets/my-riglet.nix` (or `riglets/my-riglet/default.nix` for riglets with multiple supporting files) Nix module
2. Add the needed tools, documentation, metadata
3. Define options (schema) and config (values) in this module
4. Ensure the project has a top-level `flake.nix` that uses `resolveProject` as shown above,
   so all the riglets will be exposed by the flake

## Using Riglets

In the project defining the riglets OR in another one importing it as an input flake:

1. Use the riglets in the `rigup.toml` to build rigs
2. Set an output package to export the whole rig's `home` derivation:
   `packages.<system>.<pkg> = self.rigs.<system>.<rig-name>.home`

## Design Principles

- **Knowledge-first**: Docs are the payload, tools are dependencies
  - **Declarative**: Configuration via Nix module options
  - **Composable**: Riglets build on each other
  - **Reproducible**: Nix ensures consistent tool versions
