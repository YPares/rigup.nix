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
- the configuration for these tools

By combining the relevant riglets together, you build your agent's _rig_: the tools it needs to work on your project, and the operational knowledge it needs to use those tools properly and efficiently.

`rigup` has a "knowledge-first" design: documentation is the payload, tools are dependencies

In short, `rigup` is **Claude Skills + lightweight [home management](https://github.com/nix-community/home-manager)** for your agent.

## Quick Start

This project defines example riglets, and an example rig combining them.

### Using a Rig

```bash
# Build a simple but complete agent rig:
nix build github:YPares/rigup.nix#rigs.x86_64-linux.default.home

# Discover available riglets
cat result/RIG.md

# Use the tools
./result/bin/jj --version

# Read the documentation
cat result/docs/jj-basics/SKILL.md
```

### Creating Riglets

Create a `riglets/` folder at the root of your project.
Then add to it a `<riglet-name>.nix` file:

```nix
# riglets/my-riglet.nix

{ config, pkgs, lib, riglib, ... }: {
  config.riglets.my-riglet = {
    # The tools needed by this riglet
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

    # The Skill part of the riglet. It's a file hierarchy
    # which should contain a SKILL.md entry at the top
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

    # The configuration that the tools should use
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
is to allow [_progressive disclosure_](https://en.wikipedia.org/wiki/Progressive_disclosure). (I would just have called that "cleaner layout" but apparently there's a fancy term for that which often pops up in discussions about Agent Skills nowadays)

### Creating a Rig

#### Simple Approach

Define rigs in `rigup.toml` at the top of your project:

```toml
[rigs.default]
modules = [
  # Which riglets should this 'default' rig be made of:
  "rigup.riglets.jj-basics",
  "rigup.riglets.typst-reporter",
  # If you define local riglets in your riglets/ folder, use them with:
  #"self.riglets.foo"
]

# Fill up the configuration of the riglets used in this 'default' rig,
# or override some default values
[rigs.default.config.agent.user]
name = "Alice"  # This is used by both jj-basics & typst-reporter example riglets
email = "alice@example.com"
```

Your `flake.nix` is then:

```nix
# flake.nix
{
  inputs.rigup.url = "github:YPares/rigup.nix";

  outputs = { self, rigup, ... }@inputs:
    let system = "...";
    in rigup { inherit inputs; } // {
      # Make the whole rig directly buildable as an output package:
      packages.${system}.default-rig = self.rigs.${system}.default.home;
    };
}
```

Finally, build the rig with:

```shell
nix build .#default-rig -o my-default-rig
```

The `modules` listed for each rig in your `rigup.toml` **must** match your flake inputs and what exists in your project:

- directly refer to everything under your project's `riglets/` folder as `"self.riglets.xxx"`. For instance, to use `$PROJECT_ROOT/riglets/foo.nix`, use `"self.riglets.foo"`;
- use `"<other>.riglets.xxx"` for external riglets from flakes declared in your `flake.nix` as `inputs.<other>.url = "..."`.

#### Advanced approach

Build rigs directly in Nix when a more complex configuration is needed:

```nix
{
  inputs.rigup.url = "github:YPares/rigup.nix";

  outputs = { self, rigup, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    rigup { inherit inputs; } // {
      # Override or extend with custom rigs
      rigs.${system}.custom = rigup.lib.buildRig {
        inherit pkgs;
        modules = [
          some.advanced.riglet # extra modules
          {
            # More advanced config, that e.g. requires direct access to some Nix functions
            agent.complexOption = { ... };
          }
        ];
      };

      packages.${system}.custom-rig = self.rigs.${system}.custom.home;
    };
}
```

The main reason to use a TOML file instead of listing everything in your `flake.nix` is not just because TOML is more well-known than Nix syntax.
It's mainly because pure data (that can already cover a large set of use cases) is easier to manipulate via CLI tools than Nix code (see [TODO section](#todo) below).

## Features

- **Data-driven config:** `rigup.toml` for CLI-manageable rigs
- **Auto-discovery:** Riglets from `riglets/` automatically exposed
- **Type-checked metadata:** Nix validates riglet structure
- **Nested documentation:** Skills-style SKILL.md + references/
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
└── flake.nix            # Exposes riglets & example rigs
```

## TODO

- CLI (`rigup`) for convenient rig access and manipulation of the `rigup.toml` file, via an interface like:
  - `rigup add --rig <rig> --input <flake-url> <riglet>`
  - `rigup config list --rig <rig>`
  - `rigup config set --rig <rig> foo.bar.qux <value>`
  - `rigup start --rig <rig> claude`
  - etc.
- [`minijinja`](https://github.com/mitsuhiko/minijinja)-based templating for easy modular docs that adapt based on the rig's config
- More example riglets

## Related Projects

- [`openskills`](https://github.com/numman-ali/openskills): Universal Skill loader, following Claude Skills system and manifest
- [`llm-agents.nix`](https://github.com/numtide/llm-agents.nix): Numtide's flake packaging AI coding agents and development tools

## License

MIT

______________________________________________________________________

*Built with Nix • Formatting: nixfmt-rfc-style • Uses [blueprint](https://github.com/numtide/blueprint)*
