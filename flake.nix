{
  description = "rigup - Build your AI agent's rig";

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];
    extra-trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    blueprint.url = "github:numtide/blueprint";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    inputs@{
      self,
      blueprint,
      nixpkgs,
      ...
    }:
    let
      # Recursively merge a list of attrsets (Nix "records")
      mergeRec = builtins.foldl' (acc: x: nixpkgs.lib.recursiveUpdate acc x) { };

      # `rigup` function imported directly to avoid circular dependency
      # In downstream flakes, directly use the `rigup` input as a function instead
      rigup = (import ./lib { flake = self; }).resolveProject;
    in
    mergeRec [
      # Expose packages/ and lib/ via blueprint ( https://github.com/numtide/blueprint/tree/main/docs/content/getting-started )
      (blueprint { inherit inputs; })

      # Resolve the riglets and rig defined in the project, and expose them
      (rigup {
        inherit inputs;
        projectUri = "YPares/rigup.nix";
        checkRiglets = true;
        checkRigs = true;
      })

      {
        # Make the flake itself directly usable as a function by downstream flakes
        __functor = _: self.lib.resolveProject;

        # Expose the templates
        templates = import ./templates;
      }
    ];
}
