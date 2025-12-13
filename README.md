# `rigup`

## Project Overview

**rigup** is a Nix-based system for packaging AI agent knowledge with tools.
A **riglet** is "executable and adaptable knowledge": a parameterizable _SKILL.md_-like documentation of recipes, operations and techniques paired with the Nix packages needed to execute them.
A **rig** is a project's collection of active riglets, ready to be used by an AI agent working on this project.

## Core Concepts

- **Riglet**: Nix module defining `tools` (packages) + `docs` (markdown). Knowledge-first design
- **Rig**: Project's flake.nix that composes riglets via `buildRig`
- **Cross-riglet interaction**: Modules share config (e.g., `agent.user.name` defined in jj-basics, used in typst-reporter)

## Architecture

```
rigup.nix/
├── lib/
│   ├── default.nix           # buildRig function (evaluates modules)
│   └── rigletSchema.nix      # Base module defining riglet structure
├── riglets/                  # Riglet modules
│   ├── agent-rig.nix         # Meta-docs about rig system
│   ├── jj-basics.nix         # Defines agent.user.{name,email} options
│   └── typst-reporter.nix    # Uses agent.user.name, defines typst.template
└── flake.nix                 # Exposes riglets & example rigs
```

**Usage pattern:**

```nix
rig = rigup.lib.buildRig {
  name = "alice-rig";  # optional, defaults to "agent-rig"
  inherit pkgs;
  modules = [
    rigup.riglets.jj-basics
    {
      agent.user.name = "Alice";
      agent.user.email = "alice@fake.com";
    }
  ];
};
# rig.env = combined buildEnv of all riglet tools
# rig.docs.<riglet> = per-riglet documentation derivations
```

**Writing riglet docs:**

```nix
{ config, pkgs, lib, riglib, ... }: {
  config.riglets.my-riglet = {
    tools = [ pkgs.foo ];

    # Simple single-file docs
    docs = riglib.writeDocsTree {
      files.SKILL = '' ... '';
    };

    # Or with nested references/ directory (Skills pattern)
    docs = riglib.writeDocsTree {
      files = {
        SKILL = '' ... main documentation ... '';
        references.advanced = '' ... deep dive ... '';
        references.troubleshooting = '' ... common issues ... '';
      };
    };
  };
}
```

## Key Design Decisions

1. **Any flake can declare new riglets** - projects packaging tools via a `flake.nix` can declare alongside them riglets based on those tools, by declaring several `riglets.<riglet-name>` in their `outputs`
1. **All riglets used in a rig share the same nixpkgs instance** - this ensures coherence and compatibility between the tools used by the various riglets
1. **Riglet-specific options** (e.g., `agent.user.name`) live in the `config` shared between all riglets used in the final rig
1. **minijinja for templating** (future) - simple, supports loops/conditionals for module options: derive the Skills contents from the final resolved config (via nix `builtins.toJSON`)

## Current State

Three example riglets implemented demonstrating:

- Cross-riglet option sharing (agent.user.name)
- Conditional docs (typst template styles via lib.optionalString)
- Meta-documentation (agent-rig teaches agents about riglets)

One example rig combining these three example riglets together.

### TODO

`mininija`-based templating - templating done directly in Nix code so far.

CLI (`rigup`) - just Nix lib so far.

## Related Projects

- [**envil**](https://github.com/YPares/envil): stack-based Nix env manager
- [**agent-skills**](https://github.com/YPares/agent-skills): Skill repo this evolved from (SKILL.md + scripts pattern)

## Important Notes

- Uses blueprint flake
- Formatting: nixfmt-rfc-style
- Built on Nix module system - Riglets are standard modules
