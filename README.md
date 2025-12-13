```
                                   ─────────────────────────────
                                       ╭─╮ ╶┬╴ ╭─╮   ╷ ╷ ┌─╮
                                     - ├┬╯  │  │ ┬ : │ │ ├─╯ -
                                       ╵╰─ ╶┴╴ ╰─╯   ╰─╯ ╵
                                   ─────────────────────────────
```

# Package AI agent knowledge with tools using Nix

## What is rigup?

`rigup` is a Nix-based system for packaging AI agent knowledge with the tools needed to execute it.

- **Riglet** = Executable knowledge (docs + tools + metadata)
- **Rig** = Project's collection of active riglets
- **Knowledge-first design** = Documentation is the payload, tools are dependencies

## Quick Start

**Using a rig:**
```bash
# Build a simple but complete agent environment
nix build github:YPares/rigup.nix#rigs.x86_64-linux.default.home

# Discover available riglets
cat result/RIG.md

# Use the tools
./result/bin/jj --version

# Read the documentation
cat ./result/docs/jj-basics/SKILL.md
```

**Creating riglets:**
```nix
{ config, pkgs, lib, riglib, ... }: {
  config.riglets.my-riglet = {
    tools = [ pkgs.mytool ];

    meta = {
      name = "My Riglet";
      description = "What this provides";
      whenToUse = [ "When you need X" ];
      keywords = [ "search" "terms" ];
    };

    docs = riglib.writeDocsTree {
      files.SKILL = ''
        # My Riglet Documentation
        ...
      '';
    };
  };
}
```

## Features

- **Type-checked metadata:** Nix validates riglet structure
- **Nested documentation:** Skills-style SKILL.md + references/
- **Declarative composition:** Module system for riglet interaction
- **Auto-generated manifests:** RIG.md lists all capabilities
- **Reproducible:** Nix ensures consistent tool versions

## Architecture

```
rigup.nix/
├── lib/
│   ├── default.nix      # buildRig, writeDocsTree
│   └── rigletSchema.nix # Riglet type definitions
├── riglets/
│   ├── agent-rig.nix    # Meta-documentation (read this!)
│   ├── jj-basics.nix    # Example riglet
│   └── ...
└── flake.nix            # Exposes riglets & example rigs
```

## TODO

- [ ] CLI (`rigup`) for convenient rig access
- [ ] minijinja-based templating for easy modular docs that adapt based on the rig's config
- [ ] More example riglets

## Related Projects

- [`openskills`](https://github.com/numman-ali/openskills): Universal Skill loader, following Claude Skills system and manifest
- [`llm-agents.nix`](https://github.com/numtide/llm-agents.nix): Numtide's flake packaging AI coding agents and development tools

## License

MIT

---

*Built with Nix • Formatting: nixfmt-rfc-style • Uses [blueprint](https://github.com/numtide/blueprint)*
