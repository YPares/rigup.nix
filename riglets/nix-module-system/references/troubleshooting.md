# Nix Module System: Troubleshooting

See also: [NixOS Wiki - Modules](https://wiki.nixos.org/wiki/NixOS_modules), [Import but don't import your NixOS modules](https://fzakaria.com/2024/07/29/import-but-don-t-import-your-nixos-modules) (2024)

## "The option X is defined multiple times"

**Symptom:**
```
error: The option `services.foo.bar' is defined multiple times while it's expected to be unique.
Definition values:
- In `module-a.nix': "value1"
- In `module-b.nix': "value2"
```

**Causes & Fixes:**

1. **Same module imported twice without deduplication**
   - If importing via paths: ensure same path string (not `./foo.nix` vs `../bar/foo.nix`)
   - If dynamic modules: add a `key` attribute for deduplication
   ```nix
   { key = "unique-id"; imports = [ actualModule ]; }
   ```

2. **Intentionally setting same option in multiple places**
   - Use `lib.mkForce` to override: `lib.mkForce "winning-value"`
   - Use `lib.mkDefault` for fallback: `lib.mkDefault "fallback-value"`
   - Use `lib.mkMerge` to combine: `lib.mkMerge [ config1 config2 ]`

3. **Option type doesn't support merging**
   - Some types (`str`, `int`, `bool`) can't merge multiple definitions
   - List/attrset types usually can
   - Check option definition for `lib.types.X`

## "infinite recursion encountered"

**Symptom:**
```
error: infinite recursion encountered
```

**Causes & Fixes:**

1. **Using `if` instead of `lib.mkIf`**
   ```nix
   # BAD: if evaluated immediately, might reference config being defined
   config = if config.foo.enable then { ... } else { };

   # GOOD: mkIf deferred until after config assembled
   config = lib.mkIf config.foo.enable { ... };
   ```

2. **Circular option dependencies**
   ```nix
   # BAD: a depends on b, b depends on a
   config.a = config.b + 1;
   config.b = config.a + 1;
   ```
   - Break the cycle by using `mkDefault` on one side
   - Or restructure to remove the dependency

3. **Accessing `config` in `specialArgs`**
   ```nix
   # BAD: config doesn't exist yet during specialArgs evaluation
   specialArgs = { foo = config.bar; };

   # GOOD: use _module.args instead
   modules = [{ _module.args.foo = config.bar; }];
   ```

## "The option X does not exist"

**Symptom:**
```
error: The option `foo.bar' does not exist. Definition values:
- In `my-module.nix': "some value"
```

**Causes & Fixes:**

1. **Typo in option path**
   - Double-check spelling and nesting

2. **Missing module that declares the option**
   - Add the module that defines `options.foo.bar` to your imports

3. **Setting option for optional integration**
   - Use `_module.check = false` to allow undefined options
   - Or wrap in `lib.mkIf (builtins.hasAttr ...)` to conditionally set

4. **Using wrong options prefix**
   - NixOS options: `config.services.X`
   - Home-manager: `config.programs.X` or `config.home.X`
   - Custom modules: whatever you defined in `options`

## "cannot coerce X to a string"

**Symptom:**
```
error: cannot coerce a set/list/function to a string
```

**Causes & Fixes:**

1. **Using attrset where string expected**
   ```nix
   # BAD: mkIf returns attrset, not string
   config.foo.bar = lib.mkIf condition "value";

   # GOOD: mkIf wraps the whole assignment
   config = lib.mkIf condition { foo.bar = "value"; };
   ```

2. **Interpolating non-string in string**
   ```nix
   # BAD: attrset in string interpolation
   "prefix-${someAttrset}-suffix"

   # GOOD: convert to string first
   "prefix-${builtins.toJSON someAttrset}-suffix"
   ```

## "attribute X missing"

**Symptom:**
```
error: attribute 'foo' missing
```

**Causes & Fixes:**

1. **Optional module arg not provided**
   ```nix
   # If module expects { foo, ... }: but foo not in _module.args
   # Either add to _module.args/specialArgs, or use default:
   { foo ? defaultValue, ... }:
   ```

2. **Accessing config before fully evaluated**
   - Move access to `config` section, not top-level `let`
   - Or use `lib.mkIf`/`lib.mkMerge` to defer

## Debugging Tips

**See where an option is defined:**
```nix
# In nix repl with nixos config loaded
:p config.services.foo.bar.definitionsWithLocations
```

**Trace option evaluation:**
```nix
# Add to module
config.foo = lib.traceVal config.bar;  # Prints bar's value during eval
```

**Check if option exists:**
```nix
lib.hasAttrByPath [ "services" "foo" "enable" ] options
```
