# Riglib Utility Functions

Riglets have access to `riglib` helper functions for common patterns.

## riglib.writeFileTree

Converts nested attrsets to directory trees:

- Takes a single attrset argument
- `"SKILL.md"` → `SKILL.md`
- `references."foo.md"` → `references/foo.md`
- Extensions must be included in attribute names
- Leaf values can be:
  - Strings (inline content)
  - File paths (e.g., `./SKILL.md` - useful for directory-based riglets)
  - Derivations (e.g., `pkgs.writeText` or `(pkgs.formats.<format> {}).generate`)

### Example Usage

```nix
docs = riglib.writeFileTree {
  "SKILL.md" = ''
    # My Riglet
    ...
  '';
  references = {
    "advanced.md" = ./path/to/advanced.md;
    "troubleshooting.md" = pkgs.writeText "troubleshooting" ''
      ...
    '';
  };
};
```

## riglib.useScriptFolder

Converts all files in a folder to wrapped tool packages:

- Takes a folder path as argument
- Returns a list that can be concatenated with other tools
- Each regular file in the folder becomes an executable tool
- Automatically filters out directories and non-regular files
- Each script gets wrapped via `wrapScriptPath` (filename becomes command name)

### Example Usage

```nix
tools = [ pkgs.git ] ++ riglib.useScriptFolder ./scripts
```

With this, all regular files in `./scripts/` become executable tools in the rig's `toolRoot`, named by their filename.
