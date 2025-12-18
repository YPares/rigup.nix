# See https://numtide.github.io/blueprint/main/getting-started/folder_structure/#per-system
{
  pkgs, # equivalent to 'perSystem.nixpkgs'
  #perSystem,
  ...
}:
pkgs.rustPlatform.buildRustPackage {
  pname = "extract-md-toc";
  version = "0.1.0";

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };
}
