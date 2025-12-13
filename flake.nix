{
  description = "rigup - Build your AI agent's rig";

  # Add all your dependencies here
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Load the blueprint and add custom outputs
  outputs =
    inputs:
    let
      forEachSystem = inputs.nixpkgs.lib.genAttrs inputs.nixpkgs.lib.systems.flakeExposed;
    in
    inputs.blueprint { inherit inputs; }
    // {
      # Expose riglet modules
      riglets = {
        agent-rig = import ./riglets/agent-rig.nix;
        jj-basics = import ./riglets/jj-basics.nix;
        typst-reporter = import ./riglets/typst-reporter.nix;
      };
    };
}
