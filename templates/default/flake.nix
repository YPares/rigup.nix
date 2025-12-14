{
  description = "My AI Agent Rig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rigup.url = "github:YPares/rigup.nix";
  };

  outputs =
    { self, rigup, ... }@inputs:
    let
      system = "x86_64-linux";
    in
    rigup { inherit inputs; }
    // {
      # Make the rig directly buildable
      packages.${system}.default = self.rigs.${system}.default.home;
    };
}
