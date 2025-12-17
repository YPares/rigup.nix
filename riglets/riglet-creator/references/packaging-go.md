# Packaging Go Tools with Nix

Quick reference for packaging Go applications as Nix derivations.

## Basic Application Packaging: buildGoModule

Standard approach for Go modules (most common in 2025):

```nix
{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "my-go-tool";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "example";
    repo = "my-tool";
    rev = "v${version}";
    hash = "sha256-...";
  };

  # Hash of vendored Go dependencies
  vendorHash = "sha256-...";

  meta = with lib; {
    description = "My Go tool";
    homepage = "https://example.com";
    license = licenses.mit;
    mainProgram = "my-tool";
  };
}
```

## Getting the vendorHash

To obtain the vendor hash, use a fake hash:

```nix
vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
```

Build the package and Nix will report the correct hash. Alternatively, use:

```nix
vendorHash = lib.fakeHash;
```

## Using Vendored Dependencies

If your project already vendors dependencies (has a `vendor/` directory), skip fetching:

```nix
buildGoModule {
  pname = "my-tool";
  version = "1.0.0";
  src = ./.;

  # Use existing vendor directory
  vendorHash = null;
}
```

## Two-Phase Build Process

`buildGoModule` works in two phases:

1. **Fetcher derivation**: Downloads and vendors all Go module dependencies (produces the `vendorHash`)
2. **Final derivation**: Builds the binary using the vendored dependencies

This ensures reproducibility by locking all transitive dependencies.

## Local Go Projects

For Go tools included in your riglet:

```nix
{ pkgs, ... }:

{
  config.riglets.my-riglet = {
    tools = [
      (pkgs.buildGoModule {
        pname = "my-local-tool";
        version = "0.1.0";
        src = ./scripts/my-tool;  # Contains go.mod
        vendorHash = "sha256-...";
      })
    ];
  };
}
```

## Specifying Go Version

Different Go versions are available:

```nix
buildGoModule.override { go = pkgs.go_1_22; }
```

Common versions: `go` (latest stable), `go_1_22`, `go_1_21`, etc.

## Building Without go.mod

For older projects not using modules, use `buildGoPackage` (deprecated but still available):

```nix
buildGoPackage {
  pname = "old-tool";
  goPackagePath = "github.com/example/old-tool";
  # ...
}
```

However, `buildGoModule` is strongly preferred for all new projects.

## Alternative: gomod2nix

For more control over dependency management:

```bash
# Generate nix expressions from go.mod
gomod2nix
```

This creates `gomod2nix.toml` which can be used instead of `vendorHash`.

## Further Reading

- **Official NixOS Wiki - Go**: https://nixos.wiki/wiki/Go
- **nixpkgs Go documentation**: https://ryantm.github.io/nixpkgs/languages-frameworks/go/
- **buildGoModule source**: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/go/module.nix
- **Packaging a Go app tutorial**: https://blog.ktz.me/packaging-a-go-app-for-nixos/
- **gomod2nix announcement**: https://www.tweag.io/blog/2021-03-04-gomod2nix/
