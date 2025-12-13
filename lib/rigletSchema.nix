# Base module that defines common riglet structure
{ config, pkgs, ... }:
let
  lib = pkgs.lib;
in
{
  options = {
    riglets = lib.mkOption {
      description = "Available riglets";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            tools = lib.mkOption {
              description = "List of tools this riglet provides";
              type = lib.types.listOf lib.types.package;
              default = [ ];
            };

            docs = lib.mkOption {
              description = "Documentation derivation for this riglet";
              type = lib.types.package;
            };
          };
        }
      );
      default = { };
    };
  };
}
