{
  description = "My AI Agent Rig";

  # Many riglets depend on tools provided by numtide/llm-agents.nix,
  # this tells nix to reuse the cache provided by numtide for these tools:
  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rigup.url = "github:YPares/rigup.nix";

    # `rigup` recognizes inputs which are Claude Marketplaces
    # (i.e. which have a `.claude-plugin/marketplace.json` file),
    # and special-cases them so their skills can be imported to create riglets
    # See `riglets/{algorithmic-art,frontend-design}.nix` in this repo
    anthropics-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };
  };

  outputs =
    {
      rigup,
      ...
    }@inputs:
    rigup {
      inherit inputs;
      projectUri = "my-username/my-repo";
      checkRigs = true;
    };
}
