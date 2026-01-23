# Agent Rig System

## Overview

A **rig** is a project-scoped collection of _riglets_ that provide knowledge and tools for AI agents.

## Core Concepts

### Riglet

A riglet is executable knowledge packaged with its dependencies, as a Nix module:

- **Metadata**: When should this riglet be used, is it production-ready or experimental, etc.
- **Knowledge**: SKILL.md + detailed `references/*.md` files documenting processes and recipes
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
- `genManifest`: generates a markdown+XML manifest file describing the contents of a rig, primarily for AI agent's consumption
- `mkRiglib`: creates a set of utility functions to be used to define riglet Nix modules

Defined in `{{repoRoot}}/lib/default.nix`.

#### rigup CLI tool

A Rust app. It provides convenient access to rig outputs, via commands like `rigup build` and `rigup shell`. This tool is meant for **the user** primarily. Agents should not have to call it directly.

Defined in `{{repoRoot}}/packages/rigup`

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
      mainDocFile = "SKILL.md"; # Where to start reading the docs (SKILL.md by default)
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
      disclosure = lib.mkDefault "lazy" # How much to show about riglet in manifest
        # mkDefault makes it possible for end users to override this in their rigup.toml
    };

    # Documentation file(s) (Skills pattern: SKILL.md + references/*.md)
    docs = riglib.writeFileTree {
      "SKILL.md" = ...;  # A main documentation file
      references = {       # Optional. To add deeper knowledge about more specific topics, less common recipes, etc.
                           # SKILL.md MUST mention when each reference becomes relevant
        "advanced.md" = ...;
        "troubleshooting.md" = ...;
      };
    };
    # Files can be defined either as inlined strings or nix file derivations/paths.
    # Folders can be defined either as nested attrsets or nix folder derivations/paths,
    # so if you have a ready to use folder you can do:
    #docs = ./path/to/skill/folder;

    # Configuration files (optional) for tools following the
    # [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/)
    configFiles = riglib.writeFileTree {
      # Built from a Nix attrset
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

    # EXPERIMENTAL: Prompt commands (slash commands for harnesses like Claude Code)
    # promptCommands.my-cmd = {
    #   template = "Do something specific with $ARGUMENTS";
    #   description = "What this command does";
    #   useSubAgent = false;
    # };

    # EXPERIMENTAL: MCP (Model Context Protocol) servers
    # mcpServers.my-server = {
    #   command = pkgs.my-mcp-server;  # For stdio transport
    #   transport = "stdio";
    # };
  };
}
```

The full **Nix module schema** of a riglet is defined in `{{repoRoot}}/lib/rigletSchema.nix`.

Examples of actual riglets: `{{repoRoot}}/riglets`.

### Metadata

When defining a riglet, the `meta` section specifies its purpose, maturity, and visibility. See `references/metadata-guide.md` for comprehensive details on:

- **meta.intent** - Primary focus (base, sourcebook, toolbox, cookbook, playbook)
- **meta.status** - Maturity level (stable, experimental, draft, deprecated, example)
- **meta.version** - Semantic versioning of the riglet's interface
- **meta.broken** - Temporary non-functional state flag
- **meta.disclosure** - Visibility control (none, lazy, shallow-toc, deep-toc, eager)

### Implementation Utilities

See `references/riglib-utilities.md` for details on helper functions available via `riglib`:

- **riglib.writeFileTree** - Convert nested attrsets to directory trees
- **riglib.useScriptFolder** - Convert folder of scripts into wrapped tool packages

`riglib` is defined in `{{repoRoot}}/lib/mkRiglib.nix`

### Experimental Features

**WARNING**: These features are still experimental and their schema may change.

#### Prompt Commands

Riglets can define reusable prompt templates (slash commands) for agent harnesses like Claude Code:

```nix
promptCommands.analyze = {
  template = "Analyze $1 for potential issues";
  description = "Perform code analysis";
  useSubAgent = false;  # Whether to run in a sub-agent
};
```

Templates use standard Claude command syntax: `$ARGUMENTS` for all args, or `$1`, `$2`, etc. for specific positional arguments.

#### MCP Servers

Riglets can provide MCP (Model Context Protocol) servers to extend agent capabilities:

```nix
mcpServers.my-tools = {
  command = pkgs.my-mcp-server;  # Package that starts the server
  transport = "stdio";            # stdio, sse, or http
};
```

## Cross-Riglet/Flake Interaction

Advanced patterns for composing riglets together and sharing configuration. See `references/advanced-patterns.md` for:

- Sharing configuration via `config`
- Dependencies and inheritance via `imports`
- Using packages from external flakes

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
    rigup {
      inherit inputs;
      # A unique name, used in error messages, to make it more explicit where mentioned riglets come from
      projectUri = "some-username/some-project-name";
    }
}
```

### Advanced: Directly use buildRig for complex config

For config not representable in TOML:

```nix
{
  inputs.rigup.url = "github:YPares/rigup.nix";

  outputs = { self, rigup, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    pkgs.lib.recursiveUpdate # merges both recursively, second arg taking precedence
      (rigup.lib.resolveProject {
        inherit inputs;
        projectUri = "...";
      })
      {
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
  - `toolRoot` - Folder derivation. Tools combined via nixpkgs `buildEnv` function (bin/, lib/, share/, etc.) and wrapped (when needed) to fix their XDG_CONFIG_HOME
  - `configRoot` - Folder derivation. The combined config files for the whole rig, with config files for all rig's _wrapped_ tools.
  - `meta.<riglet>` - Attrset. Per-riglet metadata, as defined by the riglet's module
  - `docAttrs.<riglet>` - Folder derivation. Per-riglet documentation folder derivations
  - `docRoot` - Folder derivation. Combined derivation with docs for all riglets (one subfolder for each)
  - `home` - Folder derivation. All-in-one directory for the rig: RIG.md manifest + .local/ + docs/ + .config/ folders
  - `shell` - Shell derivation (via `pkgs.mkShell`) exposing ready-to-use RIG_MANIFEST and PATH env vars
  - `extend` - Nix function. Adds riglets to a pre-existing rig: takes `{newName, extraModules}` and returns a new rig
  - `manifest` - A manifest for this rig, overridable with options to shorten included paths to avoid repeatedly including long explicit paths into the Nix store

`resolveProject` is defined in `{{repoRoot}}/lib/resolveProject.nix`.

## Using a Rig

The user decides how they and their agent should use the rig: either via its _shell_, _home_ or _entrypoint_ output derivations.
In any case, the agent's focus should be is the `RIG.md` manifest file. This file lists all available riglets with:

- Name
- Description
- When to use each riglet
- Keywords for searching
- Documentation paths

Agents should read this file first to understand available capabilities.

### `buildRig` output derivations

`buildRig` outputs a Nix attrset ("object") that notably contains several "all-in-one" derivations which all allow an AI agent to access the rig's tools and documentation.
Which derivation to use depends on what is the most convenient given the user's setup.
This section lists how and when to use each.

`buildRig` is defined in `{{repoRoot}}/lib/buildRig.nix`

#### `shell` output

The AI agent runs in a subshell: a `$RIG_MANIFEST` env var is set that contains the path to the RIG.md manifest the agent should read.
Also, `$PATH` is already properly set up by the subshell so all tools are readily usable.

```bash
# Start a rig as a sub-shell (the user should do that)
rigup shell ".#<rig>" [-c <command>...] # Does `nix develop ".#rigs.<system>.<rig>.shell" [-c <command>...]`

# Read the rig manifest
cat $RIG_MANIFEST
```

**Advantages of using `shell`:**

- No extra setup needed: a single command gets everything ready to use
- No risk of using an incorrect tool or config file if the agent misses a step
- Convenient to use when AI agent runs inside a terminal application (like claude-code)

#### `home` output

The AI agent reads from a complete locally-symlinked "home-like" folder.
The RIG.md manifest and an activate.sh script will be added _at the root_ of this folder.
The `activate.sh`, once sourced, provides the needed PATH.

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

**Advantages of using `home`:**

- Rig can be rebuilt without having to restart the agent's harness: home folder contents are just symlinks that can be updated, paths remain valid
- Manifest file is right next to doc files: can refer to them via short and simple relative paths
- More convenient to use in contexts where setting up env vars is impractical (e.g. AI agent running inside an IDE, like Cursor)

#### `entrypoint` output

The `entrypoint` output is special in that it **does not exist unless some riglet sets it**, by defining `config.entrypoint`.
It is mainly used to provide direct integration with common coding agent harnesses.
Similar to `home` and `shell`, `entrypoint` packages the whole rig as a Nix derivation, but this time as a wrapper shell script that starts the harness with the proper config files and CLI args.

`rigup run <flake>#<rig>` executes a rig's entrypoint.
Internally it just runs `nix run <flake>#rigs.<system>.<rig>.entrypoint`.

Claude Code integration is currently available via the `claude-code` riglet.
See `references/harness-integration.md` for more details.

**Advantages of using `entrypoint`:**

- More direct integration with the harness when such integration exists

### More efficient Markdown reading: `extract-md-toc`

This riglet (`agent-rig-system`) comes with `extract-md-toc`. This is the tool that renders the inline table of contents of the rig manifests (for riglets with `disclosure = "{shallow,deep}-toc";`).
It can also be used to extract a similar ToC out of ANY Markdown file: e.g. `extract-md-toc foo.md --max-level 3` will show all headers from `#` to `###` with their line numbers.
It can also read from stdin: `extract-md-toc - < foo.md`

Defined in `{{repoRoot}}/packages/extract-md-toc`

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
