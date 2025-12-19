{
  description = "My AI Agent Rig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rigup.url = "github:YPares/rigup.nix";
  };

  outputs =
    {
      self,
      rigup,
      flake-utils,
      ...
    }@inputs:
    rigup { inherit inputs; }
    // flake-utils.lib.eachDefaultSystem (system: {
      # Make the rig(s) directly buildable
      packages = builtins.mapAttrs (_name: rig: rig.home) self.rigs.${system};
      # Make the rig(s) exposable in sub shell
      devShells = builtins.mapAttrs (_name: rig: rig.shell) self.rigs.${system};
    });
}
