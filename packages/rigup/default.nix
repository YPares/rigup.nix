# See https://numtide.github.io/blueprint/main/getting-started/folder_structure/#per-system
{
  pkgs, # equivalent to 'perSystem.nixpkgs'
  #perSystem,
  ...
}:
pkgs.rustPlatform.buildRustPackage {
  pname = "rigup";
  version = "0.1.0";

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  meta = with pkgs.lib; {
    description = "CLI tool for managing rigup rigs";
    license = licenses.mit;
    mainProgram = "rigup";
  };
}
