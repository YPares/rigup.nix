# 'flake' is the rigup flake's 'self'
{ flake, ... }:
{
  mkRiglib = import ./mkRiglib.nix flake;
  buildRig = import ./buildRig.nix flake;
  resolveProject = import ./resolveProject.nix flake;
  genManifest = import ./genManifest.nix flake;
  rigletSchema = import ./rigletSchema.nix flake;
  discoverInputRiglets = import ./discoverInputRiglets.nix flake;
}
