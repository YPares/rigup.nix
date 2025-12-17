# Packaging Node.js/JavaScript Tools with Nix

Quick reference for packaging Node.js applications and npm packages as Nix derivations.

## Basic Application Packaging: buildNpmPackage

The modern approach for npm-based projects (2025):

```nix
{ lib, buildNpmPackage, fetchFromGitHub }:

buildNpmPackage rec {
  pname = "my-node-tool";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "example";
    repo = "my-tool";
    rev = "v${version}";
    hash = "sha256-...";
  };

  # Hash of npm dependencies cache
  npmDepsHash = "sha256-...";

  # Optional: run custom build script
  npmBuildScript = "build";

  meta = with lib; {
    description = "My Node.js tool";
    homepage = "https://example.com";
    license = licenses.mit;
    mainProgram = "my-tool";
  };
}
```

## Getting the npmDepsHash

To obtain the hash, use a fake hash initially:

```nix
npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
```

Build the package and Nix will report the correct hash in the error message. Replace with the correct hash.

## Key Points

**Modern approach**: `buildNpmPackage` creates a reproducible npm cache of dependencies without requiring auto-generated lock files.

**npm vs yarn vs pnpm**:
- For npm projects: use `buildNpmPackage` (recommended)
- For yarn projects: consider `yarn2nix` or `buildNpmPackage` with yarn support
- For pnpm projects: experimental support available

**Build scripts**: Specify custom build script with `npmBuildScript = "build"` (defaults to "build" if it exists in package.json).

## Local Project Packaging

For a local Node.js project in your riglet:

```nix
{ pkgs, ... }:

{
  config.riglets.my-riglet = {
    tools = [
      (pkgs.buildNpmPackage {
        pname = "my-local-tool";
        version = "0.1.0";
        src = ./scripts/my-tool;  # Contains package.json
        npmDepsHash = "sha256-...";
      })
    ];
  };
}
```

## Alternative: node2nix

For projects requiring more control, `node2nix` generates Nix expressions from `package.json`:

```bash
# Generate nix expressions
node2nix -i package.json

# This creates node-packages.nix, node-env.nix, default.nix
```

Then reference the generated `default.nix` in your riglet.

## Node.js Versions

Multiple Node.js versions available in nixpkgs:
- `nodejs`: Latest LTS (alias)
- `nodejs_22`: Node.js 22.x
- `nodejs_20`: Node.js 20.x

Specify version explicitly if needed:
```nix
buildNpmPackage.override { nodejs = pkgs.nodejs_20; }
```

## Further Reading

- **Official NixOS Wiki - Node.js**: https://wiki.nixos.org/w/index.php?title=Node.js
- **nixpkgs JavaScript documentation**: https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/javascript.section.md
- **node2nix repository**: https://github.com/svanderburg/node2nix
- **Managing Node.js on NixOS guide**: https://medium.com/thelinux/managing-node-js-versions-on-nixos-a-comprehensive-guide-0b452e194a1b
