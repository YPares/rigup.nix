# 'flake' is the rigup flake's 'self'
{ flake, ... }:
{
  mkRiglib = import ./mkRiglib.nix flake;
  buildRig = import ./buildRig.nix flake;
  resolveProject = import ./resolveProject.nix flake;
  genManifest = import ./genManifest.nix flake;
  rigletSchema = import ./rigletSchema.nix flake;
  listFlake = import ./listFlake.nix flake;
}
// import ./resolveClaudeMarketplace.nix flake
