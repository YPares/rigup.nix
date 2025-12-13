{
  description = "rigup - Build your AI agent's rig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      blueprint,
      ...
    }:
    let
      forEachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    blueprint { inherit inputs; }
    // {
      # Expose riglet modules
      riglets = {
        agent-rig = import ./riglets/agent-rig.nix;
        jj-basics = import ./riglets/jj-basics.nix;
        typst-reporter = import ./riglets/typst-reporter.nix;
      };

      # Expose example rigs
      rigs = forEachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          # Example rig using all available riglets
          default = self.lib.buildRig {
            inherit pkgs;
            modules = with self.riglets; [
              agent-rig
              jj-basics
              typst-reporter
              # Configure required options
              {
                agent.user.name = "Test Agent";
                agent.user.email = "test@example.com";
              }
            ];
          };
        }
      );
    };
}
