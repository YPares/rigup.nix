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
      blueprint,
      ...
    }:
    # bluprint's docs: https://github.com/numtide/blueprint/tree/main/docs/content/getting-started
    blueprint { inherit inputs; }
    # Expose the example riglets & rig
    # -- lib imported directly to avoid circular dependency
    // (import ./lib { flake = self; }).resolveProject { inherit inputs; }
    // {
      # Make the flake itself directly usable as a function by user flakes
      __functor = _: self.lib.resolveProject;

      templates = import ./templates;
    };
}
