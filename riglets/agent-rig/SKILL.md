# Agent Rig System

## Overview

A **rig** is a project-scoped collection of _riglets_ that provide knowledge and tools for AI agents.

## Core Concepts

### Riglet

A riglet is executable knowledge packaged with its dependencies, as a Nix module:

- **Metadata**: When should this riglet be used, is it production-ready or experimental, etc.
- **Knowledge**: SKILL.md + detailed references/\*.md files documenting processes and recipes
- **Tools**: Nix packages needed to execute those recipes
- **Configuration**: Settings to adapt tools' behaviour to project context

### Rig

A project-level structure that declares which riglets are active:

- Uses `buildRig` to compose riglet modules
- Builds combined tool environment declaratively
- Exposes riglets' tools and documentation

### rigup

A Nix library and CLI tool: http://github.com/YPares/rigup.nix

#### rigup Nix library

Main functions:

- `buildRig`: evaluates riglet modules and ensures they comply with the riglet schema used by rigup. Returns the rig as an attrset: `{ toolRoot = <derivation>; meta = { <riglet> = {...}; }; docAttrs = { <riglet> = <derivation>; }; docRoot = <derivation>; home = <derivation>; shell = <derivation>; }`
- `resolveProject`: inspects the `riglets/` folder of a project and its `rigup.toml` to find out which riglets and rigs it defines. It calls `buildRig` for each rig in the `rigup.toml`
- `mkRiglib`: creates a set of utility functions to be used to define riglet Nix modules
- `genManifest`: generates a markdown+XML manifest file describing the contents of a rig, primarily for AI agent's consumption

#### rigup CLI tool

It provides convenient access to rig outputs, via commands like `rigup build` and `rigup shell`. This tool is meant for **the user** primarily. Agents should not have to call it directly.

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
    # Dependency relationship/Inheritance mechanism: if B imports A, then whenever B is included in a rig, A will automatically be included too
    imports = [ self.riglets.base-riglet self.inputs.foo.riglets.bar ... ];
  
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
      description = "What this riglet provides";
      intent = "cookbook"; # What the agent should expect from this riglet
      whenToUse = [
        # When the AI Agent should read/use this riglet's knowledge, recipes and tools
        "Situation 1" # or 
        "Situation 2" # or
        ...
      ];
      keywords = [ "keyword1" "keyword2" ];
      status = "experimental"; # Maturity level
      version = "x.y.z"; # Semantic version of riglet's interface (configuration + provided methods, procedures, docs...)
      disclosure = "lazy" # How much to show about riglet in manifest
      broken = false;
    };

    # Documentation file(s) (Skills pattern: SKILL.md + references/*.md)
    docs = riglib.writeFileTree {
      "SKILL.md" = ...;  # SKILL.md MUST BE PRESENT
      references = {       # Optional. To add deeper knowledge about more specific topics, less common recipes, etc.
                           # SKILL.md MUST mention when each reference becomes relevant
        "advanced.md" = ...;
        "troubleshooting.md" = ...;
      };
    };

    # Alternatively, if you already have a folder that follows this same Agent Skill layout, you can directly reuse it:
    #docs = ./path/to/skill/folder;

    # Configuration files (optional)
    config-files = riglib.writeFileTree {
      # Built via Nix
      myapp."config.toml" = (pkgs.formats.toml {}).generate "myapp-config" {
        setting = "value";
      };
      # Read from existing file
      myapp."stuff.json" = ./path/to/stuff.json;
      # Inlined as plain text
      myapp."script.sh" = ''
        #!/bin/bash
        echo hello
      '';
    };
  };
}
```

The full **Nix module schema** of a riglet is defined in `lib/rigletSchema.nix`.

### Metadata

**About meta.intent:**
Primary focus/intent of the riglet:

- `base` - Config and/or tools without docs; usually to be imported by other riglets without being disclosed via the manifest
- `sourcebook` - Specialized facts, knowledge, terminology, or domain context for guiding thinking
- `toolbox` - Open-ended collection of tools/resources with minimal context on how they work together
- `cookbook` - Specialized techniques and patterns; arcane tricks agents may lack
- `playbook` - Behavioural instructions; step-by-step procedures for executing specific workflows

**About meta.status:**
Maturity level:

- `stable` - Production-ready, well-tested riglet
- `experimental` - (Default) Usable but may change, not fully battle-tested
- `draft` - Work in progress, incomplete
- `deprecated` - No longer maintained, use alternatives
- `example` - Pedagogical riglet for demonstrating patterns

Used to add warnings to the rig manifest.

**About meta.version:**
Semantic version (Default: `"0.1.0"`) of riglet's interface/capabilities:

- Use semver format: `MAJOR.MINOR.PATCH` (e.g., `"1.2.3"`)
- Increment MAJOR for breaking changes (renamed options, removed features)
- Increment MINOR for backwards-compatible additions (new options, new docs sections)
- Increment PATCH for backwards-compatible fixes (doc corrections, bug fixes)

**About meta.broken:**
Boolean flag (Default: `false`) indicating riglet is currently non-functional:

- Like Nix derivations' `meta.broken`, marks temporary "needs fixing" state
- Takes precedence over status in warnings in rig manifest

**About meta.disclosure:**
Enum controlling how much information about the riglet is exposed in RIG.md

- `none` - Riglet not mentioned in RIG.md. Agent won't know it exists unless manually browsing the rig or user mentions it
- `lazy` - (Default) Description, `whenToUse`, keywords, and basic metadata included. Paths to documentation provided
- `shallow-toc` - Like `lazy`, plus an auto-generated table of contents showing levels 1-2 headers from SKILL.md with line numbers for efficient navigation
- `deep-toc` - Like `shallow-toc`, but includes all header levels (1-6) for comprehensive navigation
- `eager` - Full top-level SKILL.md content directly embedded in RIG.md

This controls the information/token-count ratio:

- most riglets use `lazy` to avoid overwhelming agents during discovery
- foundational riglets use `shallow-toc` to enable efficient pinpointing of major sections
- complex riglets use `deep-toc` when agents need to navigate deeply nested documentation
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

**riglib.useScriptFolder** converts all files in a folder to wrapped tool packages:

- Takes a folder path as argument
- Returns a list that can be concatenated with other tools
- Each regular file in the folder becomes an executable tool
- Automatically filters out directories and non-regular files
- Example: `tools = [ pkgs.git ] ++ riglib.useScriptFolder ./scripts`
- Each script gets wrapped via `wrapScriptPath` (filename becomes command name)

## Cross-Riglet/Flake Interaction

### Sharing options via `config`

Riglets can reference each other's options via their `config` input arg:

```nix
# agent-identity defines agent.identity.name
options.agent.identity.name = lib.mkOption { ... };

# typst-reporter uses it
"template.typ" = ''
  ...
  #set document(author: "${config.agent.identity.name}")
  ...
'';
```

### Dependencies/Inheritance via `imports`

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

[rigs.default.config.agent.identity]
name = "Alice"
email = "alice@example.com"
```

Then use `rigup.lib.resolveProject` in your flake.nix:

```nix
{
  inputs.rigup.url = "github:YPares/rigup.nix";

  outputs = { self, rigup, ... }@inputs:
    # Using the rigup flake directly as a function is equivalent to calling
    # `rigup.lib.resolveProject`, as `rigup` defines the __functor attr.
    #
    # rigup follows the same pattern as the 'blueprint' flake (https://github.com/numtide/blueprint):
    #   - exposes one main "entrypoint" function, callable through the flake "object" itself
    #   - inspects user flake's inputs and repository's contents
    #   - constructs (part of) user flake's outputs
    rigup { inherit inputs; }
}
```

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

### `resolveProject` outputs

- `riglets.<riglet>` - Auto-discovered riglet modules
- `rigs.<system>.<rig>` - Output of `buildRig` for each discovered rig:
  - `toolRoot` - Folder derivation. Tools combined via nixpkgs `buildEnv` function (bin/, lib/, share/, etc.)
  - `configRoot` - Folder derivation. The combined XDG_CONFIG_HOME for the whole rig, with config files for all rig tools that follow the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/)
  - `meta.<riglet>` - Attrset. Per-riglet metadata, as defined by the riglet's module
  - `docAttrs.<riglet>` - Folder derivation. Per-riglet documentation folder derivations
  - `docRoot` - Folder derivation. Combined derivation with docs for all riglets (one subfolder for each)
  - `home` - Folder derivation. All-in-one directory for the rig: RIG.md manifest + .local/ + docs/ + .config/ folders
  - `shell` - Shell derivation (via `pkgs.mkShell`) exposing ready-to-use RIG_MANIFEST, XDG_CONFIG_HOME and PATH env vars
  - `extend` - Nix function. "Adds" riglets to a pre-existing rig: takes a list of riglets and returns a new rig

## Using a Rig

The user decides how they and their agent should use the rig: either via its _shell_ or _home_ output derivation.
In both cases, the agent's entrypoint is the `RIG.md` manifest file. This file lists all available riglets with:

- Name
- Description
- When to use each riglet
- Keywords for searching
- Documentation paths

Agents should read this file first to understand available capabilities.

### Via `shell` Output

The AI agent runs in a subshell: a `$RIG_MANIFEST` env var is set that contains the path to the RIG.md manifest the agent should read.
Also, `$PATH` and `$XDG_CONFIG_HOME` are already properly set up by the subshell.

```bash
# Start a rig as a sub-shell (the user should do that)
rigup shell ".#<rig>" [-c <command>...] # Does `nix develop ".#rigs.<system>.<rig>.shell" [-c <command>...]`

# Read the rig manifest
cat $RIG_MANIFEST
```

**Advantages of "shell mode":**

- No extra setup needed: a single command gets everything ready to use
- No risk of using an incorrect tool or config file if the agent misses a step
- Convenient to use when AI agent runs inside a terminal application (like claude-code)

### Via `home` Output

The AI agent reads from a complete locally-symlinked "home-like" folder.
The RIG.md manifest and an activate.sh script will be added _at the root_ of this folder.
The `activate.sh`, once sourced, provides the needed env vars (PATH and XDG_CONFIG_HOME).

```bash
# Build complete home directory with tools + docs + config as a `.rigup/<rig>` folder at the top-level of the project (the user should do that)
rigup build ".#<rig>" # Does `nix build ".#rigs.<system>.<rig>.home"`

# Read the rig manifest to see what's available
cat .rigup/<rig>/RIG.md

# Source the activation script to use the tools
source .rigup/<rig>/activate.sh && jj --version && other-tool ...

# Read documentation (paths shown in RIG.md)
ls .rigup/<rig>/docs/
cat .rigup/<rig>/docs/<riglet>/SKILL.md
```

**Advantages of "home mode":**

- Rig can be rebuilt without having to restart the agent's harness: home folder contents are just symlinks that can be updated, paths remain valid
- Manifest file is right next to doc files: can refer to them via short and simple relative paths
- More convenient to use in contexts where setting up env vars is impractical (e.g. AI agent running inside an IDE, like Cursor)

### Direct Integration with Coding Agent Harnesses

The "home" and "shell" derivations are made to be generic enough so that at least one of them should cover all user needs without too much extra manual steps, but `rigup` is planned to provide tighter, one-command setups for common coding agent harnesses such as:

- `claude-code`
- `cursor-agent`
- `copilot-cli`
- Mistral's `vibe`

These harnesses and others are already Nix-packaged in numtide's [llm-agents.nix flake](https://github.com/numtide/llm-agents.nix) (previously called "nix-ai-tools").

These integrations will be provided _as riglets too_, once `rigup` enable riglets to define an "entrypoint": a script that would be run by a new CLI command: `rigup run .#rig`.
Integrations with harnesses listed above should also serve as a reference for users and agents wishing to integrate with other harnesses.

## Adding Riglets to a Rig

In the project defining the riglets OR in another one importing it as an input flake, either add riglets and their config to the rigs defined in the top-level `rigup.toml` file, or directly edit the `flake.nix` if more advanced configuration is needed.
In both cases, the flake should call `rigup.lib.resolveProject` (or just `rigup`, which contains a `__functor` attr which defers to `resolveProject`) to discover rigs and riglets, and the rigs should be under the `rigs.<system>.<rig-name>` output.

## Creating New Riglets

In some project:

1. Create `riglets/my-riglet.nix`, or `riglets/my-riglet/default.nix` for riglets with multiple supporting files
1. Add the needed tools, documentation, metadata
1. Define options (schema) and config (values) in this module
1. Ensure the project has a top-level `flake.nix` that uses `rigup.lib.resolveProject` as mentioned above, so all the riglets will be exposed by the flake

If your rig contains `riglet-creator`, consult it for more detailed information about writing proper riglets.

## Design Principles

- **Knowledge-first**: Docs are the payload, tools are dependencies
- **Declarative**: Configuration via Nix module options
- **Composable**: Riglets build on each other
- **Reproducible**: Nix ensures consistent tool versions
