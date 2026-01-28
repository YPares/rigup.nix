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
  - Derivations (e.g., `pkgs.writeText` or `riglib.toJSON`)

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

## riglib.filterFileTree

Recursively filters a directory to keep only files with specified extensions:

- Takes two arguments: a list of extensions and a directory path
- Returns a derivation containing only files matching the specified extensions
- Preserves the directory structure
- Extensions are case-insensitive and can be specified with or without leading dots
- Useful for creating documentation bundles or resource directories

### Example Usage

```nix
# Filter to keep only markdown and text files
docs = riglib.filterFileTree ["md" "txt"] ./documentation;

# Extensions can have leading dots - both work the same
resources = riglib.filterFileTree [".png" ".jpg" ".svg"] ./assets;

# Use in riglet docs field
config.riglets.my-riglet = {
  docs = riglib.filterFileTree ["md"] ./docs;  # Only include markdown files
  # ...
};
```

This recursively walks the directory tree and creates a new derivation with only the filtered files, maintaining the original directory structure.

## riglib.renderMinijinja

Renders a Minijinja template with provided data:

- Takes an attrset with: `{ template, data, strict ? true }`
  - `template`: Path to the template file
  - `data`: Nested attrset of data to fill in the template
  - `strict`: (optional, default true) Fail if template references missing variables
- Returns a derivation containing the rendered output
- **Automatically marks the intermediate JSON data file as non-substitutable**

### Example Usage

```nix
docs = riglib.writeFileTree {
  "SKILL.md" = riglib.renderMinijinja {
    template = ./SKILL.md.jinja;
    data = {
      projectName = "my-project";
      version = "1.0.0";
    };
  };
};
```

## riglib.alwaysLocal

Marks a derivation as non-substitutable, preventing Nix from querying remote caches for it:

- Takes a single derivation argument
- Useful for cheap-to-build, project-specific derivations that will never be in a cache

### Example Usage

```nix
# Mark a generated config file as non-substitutable
configFile = riglib.alwaysLocal (
  (pkgs.formats.json {}).generate "my-config.json" { setting = "value"; }
);
```

### Utilities

`riglib.toJSON`, `toTOML`, `toXML` and `toYAML` wrap `(pkgs.formats.<format> {}).generate` with `alwaysLocal`.

