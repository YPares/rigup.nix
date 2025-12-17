{ ... }:
let
  lib = {
    writeFileTree = import ./writeFileTree.nix lib;
    buildRig = import ./buildRig.nix lib;
    resolveProject = import ./resolveProject.nix lib;
    genManifest = import ./genManifest.nix lib;
    rigletSchema = import ./rigletSchema.nix lib;
  };
in
lib
