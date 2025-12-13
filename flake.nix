{
  description = "rigup - Riglet system for AI agents";

  # Add all your dependencies here
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Load the blueprint and add custom outputs
  outputs = inputs:
    let
      bpOutputs = inputs.blueprint { inherit inputs; };

      # Helper to create system-specific riglet outputs
      forEachSystem = inputs.nixpkgs.lib.genAttrs inputs.nixpkgs.lib.systems.flakeExposed;
    in
    bpOutputs // {
      # Expose riglet modules per system
      riglets = forEachSystem (system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in {
          agent-rig = import ./riglets/agent-rig.nix;
          jj-basics = import ./riglets/jj-basics.nix;
          typst-reporter = import ./riglets/typst-reporter.nix;
        }
      );

      # Expose the riglet evaluation library
      lib = import ./lib {
        inherit (inputs.nixpkgs) lib;
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux; # Default for lib
      };
    };
}
