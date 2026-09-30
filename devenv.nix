# 
# This is a devenv module, to be imported in your own project's devenv config this way:
#
# ```yaml
# # devenv.yaml
# 
# inputs:
#   rigup: github:YPares/rigup.nix
#   ...
# imports:
#   - rigup
# ```
#
# ```nix
# # devenv.nix
#
# {
#   rigup.enable = true;
#   ...
# }
# 

{
  pkgs,
  config,
  lib,
  inputs,
  self, # self is the *final* devenv module importing this one
  ...
}:
let
  inherit (pkgs.stdenv) system;
  cfg = config.rigup;
  rigupPkgs = inputs.rigup.packages.${system};
  rigupLib = inputs.rigup.lib;
  project = rigupLib.resolveProject {
    inherit (cfg) projectUri;
    inputs = self.inputs // {
      self = self // {
        inherit (project) riglets;
      };
    };
    systems = [ system ];
  };
  rigs = project.rigs.${system};
in
{
  options.rigup = {
    enable = lib.mkEnableOption "Use rigup to build AI agent environments";
    projectUri = lib.mkOption {
      type = lib.types.str;
      description = "A project name (will be used in error messages)";
      default = "[devenv]";
    };
  };

  config = lib.mkIf config.rigup.enable {
    packages = [
      rigupPkgs.rigup
    ]
    ++ lib.mapAttrsToList (
      name: rig:
      pkgs.writeShellScriptBin "${name}-entrypoint" ''
        ${lib.getExe rig.entrypoint} "$@"
      ''
    ) (lib.filterAttrs (_: rig: rig ? entrypoint) rigs);
  };
}
