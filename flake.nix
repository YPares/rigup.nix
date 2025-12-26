{
  description = "rigup - Build your AI agent's rig";

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];
    extra-trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    blueprint.url = "github:numtide/blueprint";
    # Pinning ref due to https://github.com/numtide/llm-agents.nix/issues/1574
    llm-agents.url = "github:numtide/llm-agents.nix/78eafa553ae1b64eec5e8aa54810568c5cc0de3c";
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
    // (import ./lib { flake = self; }).resolveProject {
      inherit inputs;
      checkRigs = true;
    }
    // {
      # Make the flake itself directly usable as a function by user flakes
      __functor = _: self.lib.resolveProject;

      templates = import ./templates;
    };
}
