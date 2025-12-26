# Advanced Cross-Riglet Patterns

Once comfortable with basic riglet structure, these patterns enable sophisticated composition and configuration sharing.

## Sharing Configuration via config

Riglets can reference each other's options via their `config` input arg:

```nix
# agent-identity defines agent.identity.name
options.agent.identity.name = lib.mkOption { ... };

# typst-reporter uses it
"template.typ" = ''
  ...
  #set document(author: "${config.agent.identity.name}")
  ...
'';
```

This allows one riglet to define configuration options that other riglets consume, enabling centralized settings.

## Dependencies and Inheritance via imports

If a riglet depends on another, use `imports` with `self.riglets.*`:

```nix
self:
{ riglib, ... }: {
  # Import the base riglet - evalModules deduplicates if both are in the rig
  imports = [ self.riglets.base-riglet ];

  config.riglets.advanced-riglet = { ... };
}
```

**IMPORTANT:** Always use `self.riglets.*` for imports, never path-based imports like `./base-riglet.nix`. The `self.riglets.*` form ensures proper deduplication.

For riglets from external flakes:

```nix
imports = [ self.inputs.other-flake.riglets.some-riglet ];
```

This relationship ensures that whenever your riglet is included, its dependencies are automatically included too.

## Using Packages from External Flakes

Access packages from external flakes via `self.inputs`:

```nix
self:
{ pkgs, system, riglib, ... }: {
  config.riglets.my-riglet = {
    tools =
      # Use the provided system to select the right platform
      # (`system` arg == `pkgs.stdenv.hostPlatform.system` == `pkgs.system` but last one is deprecated)
      let someFlakePkgs = self.inputs.some-flake.packages.${system};
      in [
        someFlakePkgs.foo
        someFlakePkgs.bar
        pkgs.git
      ];
  };
}
```

This allows riglets to compose tools and packages from multiple upstream flakes, pinned to specific revisions.
