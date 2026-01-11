# See https://numtide.github.io/blueprint/main/getting-started/folder_structure/#per-system
{ pkgs, ... }:
pkgs.mkShell {
  name = "rigup-dev";
  description = "Development shell for rigup";

  buildInputs = with pkgs; [
    cargo
    rustc
    rust-analyzer
    clippy
    rustfmt
    just
  ];
}
