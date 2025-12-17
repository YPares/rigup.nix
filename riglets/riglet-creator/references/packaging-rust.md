# Packaging Rust Tools with Nix

Quick reference for packaging Rust applications as Nix derivations.

## Basic Application Packaging: buildRustPackage

Standard approach using `rustPlatform.buildRustPackage`:

```nix
{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "my-rust-tool";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "example";
    repo = "my-tool";
    rev = "v${version}";
    hash = "sha256-...";
  };

  # Hash of all Cargo dependencies
  cargoHash = "sha256-...";

  meta = with lib; {
    description = "My Rust tool";
    homepage = "https://example.com";
    license = licenses.mit;
    mainProgram = "my-tool";
  };
}
```

## Getting the cargoHash

Use a fake hash initially:

```nix
cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
```

Build the package and Nix will provide the correct hash. Replace with it.

## Alternative: Using Cargo.lock Directly

Simpler approach when you have `Cargo.lock`:

```nix
{ lib, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "my-tool";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  # Reference Cargo.lock directly
  cargoLock.lockFile = ./Cargo.lock;

  meta = with lib; {
    description = "My Rust tool";
    license = licenses.mit;
  };
}
```

This is often simpler for local projects where you already have a committed `Cargo.lock`.

## Local Rust Projects

For Rust tools included in your riglet:

```nix
{ pkgs, system, ... }:

{
  config.riglets.my-riglet = {
    tools = [
      (pkgs.rustPlatform.buildRustPackage {
        pname = "my-local-tool";
        version = "0.1.0";
        src = ./scripts/my-tool;  # Contains Cargo.toml and Cargo.lock
        cargoLock.lockFile = ./scripts/my-tool/Cargo.lock;
      })
    ];
  };
}
```

## Advanced: Faster Builds with Alternative Tools

For larger projects, these tools can provide faster incremental builds by separating dependencies from application code:

- **crane**: Modern, composable Rust build system for Nix
- **naersk**: Minimal, fast Rust builds
- **crate2nix**: Generates Nix expressions from Cargo.toml

Example with crane:
```nix
{ crane, system }:

let
  craneLib = crane.mkLib pkgs;
in
craneLib.buildPackage {
  src = ./.;
  # Crane automatically handles Cargo.lock
}
```

## 2025 Development: devenv Integration

Modern Rust development environments can use `devenv` with `languages.rust.import` for automatic packaging.

## Further Reading

- **Official NixOS Wiki - Rust**: https://wiki.nixos.org/wiki/Rust
- **nixpkgs Rust documentation**: https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/rust.section.md
- **How to package a Rust app**: https://m7.rs/blog/2022-11-01-package-a-rust-app-with-nix/
- **devenv Rust guide (2025)**: https://devenv.sh/blog/2025/08/22/closing-the-nix-gap-from-environments-to-packaged-applications-for-rust/
- **Building from workspaces**: https://www.tweag.io/blog/2022-09-22-rust-nix/
