# Nix Module System: Dark Corners

Practical knowledge about `lib.evalModules` that's hard to find in official docs.

**Sources:**
- [nixpkgs/lib/modules.nix](https://github.com/NixOS/nixpkgs/blob/master/lib/modules.nix) — implementation
- [Module system docs](https://github.com/NixOS/nixpkgs/blob/master/doc/module-system/module-system.chapter.md) — official chapter
- [nix.dev deep dive](https://nix.dev/tutorials/module-system/deep-dive.html) — tutorial
- [noogle.dev evalModules](https://noogle.dev/f/lib/modules/evalModules) — function reference

## Module Identity & Deduplication

When the same module is included multiple times (e.g., via imports from different places), `evalModules` deduplicates by identity:

**Path-based modules**: Deduplicated by path string
```nix
modules = [ ./foo.nix ./foo.nix ];  # Same path → evaluated once
```

**Function/attrset modules**: Deduplicated by `key` attribute
```nix
# Without key: each inclusion is separate (can cause "defined multiple times" errors)
modules = [ myModule myModule ];  # Evaluated twice!

# With key: deduplicated
myModule = {
  key = "my-unique-module-id";
  imports = [ actualModule ];
};
modules = [ myModule myModule ];  # Evaluated once
```

Use `key` when you wrap modules dynamically and need deduplication across import chains.

## Module Arguments

### `_module.args` vs `specialArgs`

Both inject arguments into module functions, but differ in timing:

```nix
evalModules {
  specialArgs = { foo = "available during option declaration"; };
  modules = [{
    _module.args = { bar = "only available in config, not options"; };
  }];
}
```

| | `specialArgs` | `_module.args` |
|---|---|---|
| Available in `options = { ... }` | ✓ | ✗ |
| Available in `config = { ... }` | ✓ | ✓ |
| Can reference `config` | ✗ | ✓ |

**Rule of thumb**: Use `specialArgs` for things needed to *declare* options (like `lib`), use `_module.args` for runtime values (like `pkgs`).

### `_module.check`

Disable "unknown option" errors:
```nix
{ _module.check = false; }
```

Useful when modules set options that might not exist (e.g., optional integrations).

### `_module.freeformType`

Allow arbitrary attributes in config without declaring options:
```nix
{
  _module.freeformType = lib.types.attrsOf lib.types.anything;

  # Now any attribute is allowed without explicit options
  whatever.you.want = "works";
}
```

## Priority & Merging

### `mkDefault` / `mkForce` / `mkOverride`

Control which definition wins when multiple modules set the same option:

```nix
# Priority scale: lower number wins
lib.mkOverride 1000 "default priority"    # Same as mkDefault
lib.mkOverride 100 "normal priority"      # Default when no mk* used
lib.mkOverride 50 "force priority"        # Same as mkForce

# Shorthands
lib.mkDefault x  # mkOverride 1000 - easily overridden
lib.mkForce x    # mkOverride 50 - overrides most things
```

### `mkMerge`

Combine multiple config fragments:
```nix
config = lib.mkMerge [
  { services.foo.enable = true; }
  (lib.mkIf condition { services.foo.port = 8080; })
];
```

### `mkIf` (it's not just `if`)

`lib.mkIf` is *not* the same as Nix's `if`:
```nix
# Nix if: evaluated immediately, fails if option doesn't exist
config = if condition then { foo = 1; } else { };

# lib.mkIf: deferred, only evaluated if condition is true
config = lib.mkIf condition { foo = 1; };
```

`mkIf` prevents "infinite recursion" errors when the condition depends on other config values.

### `mkBefore` / `mkAfter` / `mkOrder`

For list-type options, control ordering:
```nix
{
  environment.systemPackages = lib.mkBefore [ earlyPkg ];  # Prepend
  environment.systemPackages = lib.mkAfter [ latePkg ];   # Append
  environment.systemPackages = lib.mkOrder 500 [ midPkg ]; # Explicit order
}
```

## Disabling Modules

Remove a module from evaluation:
```nix
{
  disabledModules = [
    "services/web-servers/nginx.nix"  # Path relative to modules root
    someImportedModule                 # Direct reference
  ];
}
```

Useful for replacing NixOS modules with custom implementations.

## Common Errors & Fixes

See [references/troubleshooting.md](references/troubleshooting.md) for detailed error explanations.

**Quick fixes:**
- "The option ... is defined multiple times" → Add `key` attribute or use `lib.mkForce`/`lib.mkMerge`
- "infinite recursion encountered" → Use `lib.mkIf` instead of `if`, or check for circular dependencies
- "The option ... does not exist" → Check spelling, or set `_module.check = false` for optional deps
