{
  description = "Minimal AI Agent Rig";

  # Many riglets depend on tools provided by numtide/llm-agents.nix,
  # this tells nix to reuse the cache provided by numtide for these tools:
  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rigup.url = "github:YPares/rigup.nix";
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
