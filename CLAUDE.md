# CLAUDE.md

## Project Overview

**rigup** is a Nix-based system for packaging AI agent knowledge with tools. A **riglet** is "executable knowledge" - SKILL.md documentation paired with the Nix packages needed to execute those processes. A **rig** is a project's collection of active riglets.

## Core Concepts

- **Riglet**: Nix module defining `tools` (packages) + `docs` (markdown). Knowledge-first design.
- **Rig**: Project's flake.nix that composes riglets via `buildRig`
- **Cross-riglet interaction**: Modules share config (e.g., `user.name` defined in jj-basics, used in typst-reporter)

## Architecture

```
rigup.nix/
├── lib/default.nix           # buildRig function (evaluates modules)
├── riglets/                  # Riglet modules
│   ├── agent-rig.nix         # Meta-docs about rig system
│   ├── jj-basics.nix         # Defines user.{name,email} options
│   └── typst-reporter.nix    # Uses user.name, defines typst.template
└── flake.nix                 # Exposes riglets (system-agnostic)
```

**Usage pattern:**
```nix
rig = rigup.lib.buildRig {
  inherit pkgs;
  modules = [
    rigup.riglets.jj-basics
    { user.name = "Alice"; user.email = "alice@fake.com"; }
  ];
};
# rig.tools = combined buildEnv
# rig.docs.<riglet> = per-riglet documentation
```

## Key Design Decisions

1. **Riglets live in flakes at top-level** - `input-flake.riglets.<riglet-name>`
1. **All riglets used in a rig share the same nixpkgs instance** - this ensures coherence and compatibility between the tools used by the various Skills
1. **Riglet-specific options live at top-level** - e.g., `user.name`
1. **minijinja for templating** (future) - simple, supports loops/conditionals for module options: derive the Skills contents from the final resolved config (via nix `builtins.toJSON`)

## Current State

Three example riglets implemented demonstrating:
- Cross-riglet option sharing (user.name)
- Conditional docs (typst template styles via lib.optionalString)
- Meta-documentation (agent-rig teaches agents about riglets)

CLI (`rigup`) not yet implemented - just Nix lib so far.

## Related Projects

- [**envil**](https://github.com/YPares/envil): stack-based Nix env manager
- [**agent-skills**](https://github.com/YPares/agent-skills): Skill repo this evolved from (SKILL.md + scripts pattern)

## Important Notes

- Uses blueprint flake
- Formatting: nixfmt-rfc-style
- Built on Nix module system - Riglets are standard modules
