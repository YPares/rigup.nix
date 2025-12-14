{
  description = "rigup - Build your AI agent's rig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      blueprint,
      ...
    }:
    let
      # Import lib functions directly to avoid circular dependency
      rigupLib = import ./lib { };
    in
    blueprint { inherit inputs; }
    # Expose the example riglets
    // rigupLib.resolveRigs { inherit inputs; }
    // {
      # Makes the flake itself directly usable as a function
      __functor = self: self.lib.resolveRigs;

      # Templates for bootstrapping new projects
      templates.default = {
        path = ./templates/default;
        description = "Basic rigup project with example riglet";
        welcomeText = ''
          # Project initialized!

          # Next steps

          1. Edit riglets/my-first-riglet.nix to add your tools and documentation
          2. Update rigup.toml to configure your rig
          3. Build your rig: nix build
          4. Explore the output: cat result/RIG.md
          5. Learn more: https://github.com/YPares/rigup.nix
        '';
      };
    };
}
