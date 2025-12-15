```
                                ─────────────────────────────────
                                      ╭─╮ ╶┬╴ ╭─╮   ╷ ╷ ┌─╮     
                                  ──  ├┬╯  │  │ ┬ : │ │ ├─╯  ──
                                      ╵╰─ ╶┴╴ ╰─╯   ╰─╯ ╵       
                                ─────────────────────────────────
```

# Self-Contained, Modular, Reusable AI Agent Skills

`rigup` is a Nix-based system for packaging AI agent skills with the tools and config needed to execute them.

A _riglet_ is _executable knowledge_:

- metadata to indicate to your agent what this riglet is for and when it is useful to consult it
- a set of operations, instructions, processes, a.k.a a new [skill](https://code.claude.com/docs/en/skills) for your agent. These instructions are _lazily_ loaded: your agent reads them when it needs to, or is prompted to
- the tools (nix packages) needed to execute these instructions
- the configuration for these tools (if any)
- the riglets it depends from (if any), ie. those it builds upon, ensuring that tools and knowledge from these base riglets are always available too to your agent

By combining the relevant riglets together, you build your agent's _rig_: the tools it needs to work on your project, and the operational knowledge it needs to use those tools properly and efficiently.

`rigup` has a "knowledge-first" design: documentation is the payload, tools are dependencies

In short, `rigup` is **Claude Skills + explicit Skill dependencies + lightweight [home management](https://github.com/nix-community/home-manager)** for your agent.

## Quick start

You can create a new project from the template provided by this repository, or even directly build
the example rig defined here.

### Create a new project

```bash
# Initialize a new project from the template
mkdir new-project && cd new-project && nix flake init -t github:YPares/rigup.nix

# Build your rig
nix build

# Explore the rig
cat result/RIG.md
```

This creates a basic project structure with an example riglet. Edit `riglets/my-first-riglet.nix` and `rigup.toml` to customize it.

### Use the example rig from this project

This project defines example riglets, and an example rig combining them.

```bash
# Build a simple but complete agent rig:
nix build github:YPares/rigup.nix#rigs.x86_64-linux.example-rig.home

# Discover available riglets
cat result/RIG.md

# Use the tools
./result/bin/jj --version

# Read the documentation
cat result/docs/jj-basics/SKILL.md
```

## Deeper dive

This section covers the general workflow of defining and editing riglets and rigs.

### Creating a riglet

Riglets are a simple use case of [Nix modules](https://nix.dev/tutorials/module-system/a-basic-module/).

Concretely, this means a riglet (in its most general form) is a `(config, dependencies) -> data` Nix function, where:

- `config` is the final config of the rig which the riglet is part of,
- `data` is a dictionary-like structure ("attribute set" in Nix lingo) providing nested fields that will _themselves_ contribute to the final aggregated config

Create a `riglets/` folder at the root of your project.
Then add to it a `<riglet-name>.nix` file:

```nix
# riglets/my-riglet.nix

# - config is the final aggregated config of the rig using my-riglet,
# - inputs is your flake inputs, as passed to `rigup`,
# - pkgs is your usual imported nixpkgs,
# - riglib is injected by rigup, and contains utility functions to build riglets
{ config, inputs, pkgs, riglib, ... }: {

  # (Optional) Which riglet(s) should `my-riglet` depend from.
  # If `my-riglet` is added to a rig, this ensures that its dependencies
  # are always added as well
  imports = [
    ./path/to/dependency.nix  # A locally defined riglet
    inputs.foo.riglets.bar    # A riglet exposed by an input flake
  ]

  # Each riglet must declare itself under config.riglets.<riglet-name>
  config.riglets.my-riglet = {

    # (Optional) The tools needed by this riglet
    tools = [ pkgs.mytool ];

    # The metadata that will enable your agent to know what this riglet
    # provides and when it should be consulted
    meta = {
      name = "My Riglet";
      description = "What this provides";
      whenToUse = [ "When you need X" ];
      keywords = [ "search" "terms" ];
      status = "draft";
      version = "0.1.0";
    };

    # The Skill part of the riglet. It is a file hierarchy that should contain a
    # SKILL.md entry right under the root
    docs = riglib.writeFileTree {
      # Use inline strings...
      "SKILL.md" = ''
        # My Riglet Documentation

        ...

        For more advanced cases, see references/advanced-cases.md
      '';
      references = {
        # ...or local file paths...
        "advanced-cases.md" = ./path/to/advanced-cases.md;
        # ...or derivations that build a file
        "foo.md" = pkgs.writeText "foo.md" (mkFooContents x y z t);
      };
    };

    # (Optional) The configuration that the tools should use
    # These will go under `.config` in the final "home directory" of the rig
    config-files = riglib.writeFileTree {
      # .config/mytool/config.toml
      mytool."config.toml" = ''
        setting = "value"
      '';
    };

  };

}
```

Just as with regular Agent Skills, the point of separating the docs into several files
is to allow [_progressive disclosure_](https://en.wikipedia.org/wiki/Progressive_disclosure).
When using AI Agents, this is important because [context](https://www.ibm.com/think/topics/context-window) is on a budget, and agents should not have to read [more documentation than they need](https://medium.com/@cdcore/mcp-is-broken-and-anthropic-just-admitted-it-7eeb8ee41933) to complete a task.

#### Alternative structure

Instead of `riglets/<riglet-name>.nix`, you can define your riglet as `riglets/<riglet-name>/default.nix` to add supporting files next to it:

```
riglets/
├── simple-riglet.nix          # Single-file riglet
└── complex-riglet/            # Directory-based riglet
    ├── default.nix            # Main riglet definition
    ├── SKILL.md               # Referenced in default.nix via ./SKILL.md
    └── references/
        └── advanced.md        # Referenced in default.nix via ./references/advanced.md
```

This is useful to break up a riglet into various Nix or raw text files to make it more manageable.
`rigup` will discover and treat both layouts identically.

### Creating a rig

#### Simple option: `rigup.toml`

Define rigs in `rigup.toml` at the top of your project:

```toml
# Riglets to include in this rig, grouped by source
[rigs.default.riglets]
rigup = ["jj-basics", "typst-reporter"]  # From the rigup flake input
self = ["my-local-riglet"]               # From your riglets/ folder

# Configuration for the riglets used in this rig
[rigs.default.config.agent.user]
name = "Alice"  # This is used by both jj-basics & typst-reporter example riglets
email = "alice@example.com"
```

Your `flake.nix` should be:

```nix
{
  inputs.rigup.url = "github:YPares/rigup.nix";

  outputs = { self, rigup, ... }@inputs:
    let system = "...";
    in rigup { inherit inputs; } // {
      # Expose the whole rig directly as an output package, so it is easy to build
      packages.${system}.default-rig = self.rigs.${system}.default.home;
    };
}
```

Finally, build the rig with:

```shell
nix build .#default-rig -o my-default-rig
```

The riglets listed in your `rigup.toml` **must** match your flake inputs and what exists in your project. As a general case:

```toml
[rigs.my-rig.riglets]
some-flake = ["foo", "bar"]
```

means that your `flake.nix` has a `some-flake` input that exposes the `riglets.foo` and `riglets.bar` outputs.
`self` is just a special case of that, as every flake has an implicit `self` input which is the flake itself.

**NOTE:** The main reason to use a TOML file instead of always defining everything as Nix code is not _just_ because TOML is (much) more well-known than Nix syntax.
It is mainly because pure data (that can already cover a large set of use cases) is easier to manipulate via CLI tools than Nix code (see [TODO section](#todo) below).

#### Advanced option: combine with Nix

...that being said, building rigs directly in Nix (if you need the full Nix power to write your rig's configuration) is totally supported:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.rigup.url = "github:YPares/rigup.nix";
  inputs.foo.url = "github:bar/foo";

  outputs = { self, rigup, nixpkgs, foo, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    rigup { inherit inputs; } // {
      # Override or extend with custom rigs
      rigs.${system}.custom = rigup.lib.buildRig {
        inherit inputs pkgs;
        modules = [
          self.riglets.aaa # Will use `$PROJECT_ROOT/riglets/{aaa.nix,aaa/default.nix}`
          foo.riglets.bbb  # Use external riglets defined by our inputs
          foo.riglets.ccc
          # Extra config is given in the form of a simple in-line Nix module,
          # with or without `{ config, pkgs, riglib, ... }` arguments
          {
            config = {
              # More advanced config, that e.g. requires direct access to some Nix functions,
              # or even takes the form of Nix functions:
              aaa-config.i-need-a-derivation = pkgs.someDerivationBuilder "..." "........";
              bbbModuleOpts.conditions.is-x-y-pair-valid = x: y: x * y <= 42.420000000000001;
            }
          }
        ];
      };

      # (Same as before) Optionally expose more directly whole rigs as output packages
      packages.${system}.custom-rig = self.rigs.${system}.custom.home;
    };
}
```

**IMPORTANT:** This makes the `rigup.toml` entirely _optional_, but it is **still necessary** to use `rigup { inherit inputs; }` to construct your flake's outputs.
This is so `rigup` can discover which riglets are defined in your `$PROJECT_ROOT/riglets/` and set up the `riglets` output of your flake.

As the above suggests, you can totally mix both options: define some simple rigs in the `rigup.toml` and some advanced ones in Nix code.
Although, prefer splitting you rigs' definitions in separate Nix files rather than declaring everything in your `flake.nix`, the example above is just for the sake of concision.

## Features

- **Data-driven config:** `rigup.toml` for CLI-manageable rigs
- **Auto-discovery:** Riglets from `riglets/` automatically exposed
- **Type-checked metadata:** Nix validates riglet structure
- **Lazily readable documentation:** Skills-style SKILL.md + references/
- **Declarative composition:** Module system for riglet interaction
- **Auto-generated manifests:** RIG.md lists all capabilities
- **Reproducible:** Nix ensures consistent tool versions

## Architecture

```
rigup.nix/
├── lib/
│   ├── default.nix      # riglib (common functions to define riglets)
│   ├── manifest.nix     # RIG.md generation
│   └── rigletSchema.nix # Riglet type definitions
├── riglets/
│   ├── agent-rig.nix    # Meta-documentation (a riglet about the agent rig system)
│   └── ...              # Example riglets
├── rigup.toml           # Declares the example rig
└── flake.nix            # Exposes the Nix library + the above riglets & rig as outputs
```

## TODO

- Add `checks` to riglets: automated and/or through-agent testing that a riglet is working as intended
- `rigup` CLI tool for convenient rig access and manipulation of the `rigup.toml` file, via an interface like:
  - `rigup add --rig <rig> --input <flake-url> <riglet>`
  - `rigup config list --rig <rig>`
  - `rigup config set --rig <rig> foo.bar.qux <value>`
  - `rigup start --rig <rig> claude`
  - etc.
- [`minijinja`](https://github.com/mitsuhiko/minijinja)-based templating for easy modular docs that adapt based on the rig's config
- More example riglets

## Related projects

- [`openskills`](https://github.com/numman-ali/openskills): Universal Skill loader, following Claude Skills system and manifest
- [`llm-agents.nix`](https://github.com/numtide/llm-agents.nix): Numtide's flake packaging AI coding agents and development tools

## License

MIT

______________________________________________________________________

*Built with Nix • Formatting: nixfmt-rfc-style • Uses [blueprint](https://github.com/numtide/blueprint)*
