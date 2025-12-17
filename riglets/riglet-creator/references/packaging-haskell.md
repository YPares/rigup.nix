# Packaging Haskell Tools with Nix

Quick reference for packaging Haskell applications as Nix derivations.

## Basic Concepts

**haskellPackages**: A large set containing Haskell packages from Hackage and Stackage. It's a synonym for `haskell.packages.ghcXYZ` where XYZ is the current default GHC version.

**Version selection**:
- Stackage packages: Use versions from current Stackage LTS snapshot
- Other packages: Use latest version from Hackage

## Simple Development Shell

For quick Haskell development in a riglet:

```nix
{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs.haskellPackages; [
    (ghcWithPackages (hpkgs: with hpkgs; [
      aeson
      text
      bytestring
    ]))
    cabal-install
  ];
}
```

## Using developPackage

For projects with a `.cabal` file, use `developPackage`:

```nix
{ pkgs, ... }:

{
  config.riglets.my-riglet = {
    tools = [
      (pkgs.haskellPackages.developPackage {
        root = ./scripts/my-tool;  # Directory containing .cabal file
        name = "my-tool";
      })
    ];
  };
}
```

`developPackage` is a wrapper around `callCabal2nixWithOptions` that automatically converts a Cabal file to a Nix expression.

## Manual Package Definition

For more control, define a Haskell package manually:

```nix
{ lib, haskellPackages, fetchFromGitHub }:

haskellPackages.mkDerivation {
  pname = "my-haskell-tool";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "example";
    repo = "my-tool";
    rev = "v1.0.0";
    hash = "sha256-...";
  };

  libraryHaskellDepends = with haskellPackages; [
    aeson
    text
  ];

  executableHaskellDepends = with haskellPackages; [
    optparse-applicative
  ];

  license = lib.licenses.mit;
}
```

## Using callCabal2nix

Convert a Cabal file to Nix expression on-the-fly:

```nix
{ haskellPackages }:

haskellPackages.callCabal2nix "my-tool" ./path/to/cabal/project { }
```

The third argument is for overriding dependencies if needed.

## Specifying GHC Version

Use a specific GHC version:

```nix
{ pkgs }:

pkgs.haskell.packages.ghc965.developPackage {
  root = ./.;
}
```

Available: `ghc98`, `ghc965`, `ghc947`, `ghc928`, etc.

## Known Limitations (2025)

- About 50% of packages in `haskellPackages` are marked as broken (deprecated/unmaintained)
- GHCJS support removed; use `pkgsCross.ghcjs` instead
- GHC versions with integer-simple removed (as of Sept 2025)

## Quick Tool Packaging Example

Packaging a Haskell CLI tool in a riglet:

```nix
_:
{ pkgs, riglib, ... }: {
  config.riglets.my-riglet = {
    tools = [
      (pkgs.haskellPackages.callCabal2nix "my-tool" ./scripts/my-tool { })
      pkgs.haskellPackages.cabal-install
    ];

    docs = riglib.writeFileTree {
      "SKILL.md" = ''
        # My Riglet

        Use `my-tool` for...
      '';
    };

    meta = {
      name = "My Haskell Riglet";
      description = "Provides my-tool for X";
    };
  };
}
```

## Further Reading

- **Official NixOS Wiki - Haskell**: https://wiki.nixos.org/wiki/Haskell
- **nixpkgs Haskell documentation**: https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/haskell.section.md
- **Haskell package user's guide**: https://haskell4nix.readthedocs.io/nixpkgs-users-guide.html
- **Incremental packaging guide**: https://www.haskellforall.com/2022/08/incrementally-package-haskell-program.html
- **Gabriella439's Haskell-Nix guide**: https://github.com/Gabriella439/haskell-nix
