# Riglet Metadata Guide

When defining a riglet's `meta` section, you can specify several fields to describe its purpose, maturity, and visibility.

Most of these metadata elements are NOT meant to be overriden by end users when building their rig, EXCEPT for `meta.disclosure`.

## meta.intent

Primary focus/intent of the riglet:

- `base` - Config and/or tools without docs; usually to be imported by other riglets without being disclosed via the manifest
- `sourcebook` - Specialized facts, knowledge, terminology, or domain context for guiding thinking
- `toolbox` - Open-ended collection of tools/resources with minimal context on how they work together
- `cookbook` - Specialized techniques and patterns; arcane tricks agents may lack
- `playbook` - Behavioural instructions; step-by-step procedures for executing specific workflows

## meta.status

Maturity level:

- `stable` - Production-ready, well-tested riglet
- `experimental` - (Default) Usable but may change, not fully battle-tested
- `draft` - Work in progress, incomplete
- `deprecated` - No longer maintained, use alternatives
- `example` - Pedagogical riglet for demonstrating patterns

Used to add warnings to the rig manifest.

## meta.version

Semantic version (Default: `"0.1.0"`) of riglet's interface/capabilities:

- Use semver format: `MAJOR.MINOR.PATCH` (e.g., `"1.2.3"`)
- Increment MAJOR for breaking changes (renamed options, removed features)
- Increment MINOR for backwards-compatible additions (new options, new docs sections)
- Increment PATCH for backwards-compatible fixes (doc corrections, bug fixes)

## meta.broken

Boolean flag (Default: `false`) indicating riglet is currently non-functional:

- Like Nix derivations' `meta.broken`, marks temporary "needs fixing" state
- Takes precedence over status in warnings in rig manifest

## meta.disclosure

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

Riglets overriding this default SHOULD use `nixpkgs.lib.mkDefault`, so end users may still easily change it when building their rig.

## Tool Configuration Files

**configFiles** provides configuration for tools:

- Uses `riglib.writeFileTree` to create `.config/` directory structure
- Follows XDG Base Directory specification
- All riglets' configFiles are merged into `.config/`
- Example: `jj."config.toml"` → `.config/jj/config.toml`
- Can use `riglib.toJSON`/`YAML`/`TOML`/`XML` to generate config files from Nix data
- Can use plain strings for shell scripts or plain text configs
