# Auto-discover riglets and resolve rigs from rigup.toml
{ rigupLib, ... }:

# Resolve rigs from rigup.toml configuration
# Arguments:
#   - inputs: flake inputs attrset (must include self and nixpkgs)
#   - systems: list of systems to generate rigs for (e.g., ["x86_64-linux"])
# Returns: { riglets = {...}; rigs.<system>.<rig> = {...}; }
{
  inputs,
  systems ? inputs.nixpkgs.lib.systems.flakeExposed,
}:
let
  # Read rigup.toml from repository root
  rigupToml = builtins.fromTOML (builtins.readFile (inputs.self + "/rigup.toml"));

  # Auto-discover all riglets from riglets/ directory
  rigletsDir = inputs.self + "/riglets";
  rigletFiles = builtins.readDir rigletsDir;

  # Expose all .nix files as riglets
  riglets = builtins.listToAttrs (
    builtins.map (name: {
      name = builtins.replaceStrings [ ".nix" ] [ "" ] name;
      value = rigletsDir + "/${name}";
    }) (builtins.filter (name: builtins.match ".*\\.nix" name != null) (builtins.attrNames rigletFiles))
  );

  # Resolve a module reference like "self.riglets.foo" or "input.riglets.bar"
  # Returns the actual riglet module path/attrset
  resolveModuleRef =
    ref:
    let
      parts = builtins.split "\\." ref;
      # parts will be ["input-name" "riglets" "riglet-name"] with separators
      # Filter out the separators (empty strings from split)
      cleanParts = builtins.filter (x: builtins.isString x && x != "") parts;

      inputName = builtins.elemAt cleanParts 0;
      rigletName = builtins.elemAt cleanParts 2;
    in
    if inputName == "self" then riglets.${rigletName} else inputs.${inputName}.riglets.${rigletName};

  # Build rigs for all systems
  rigs = builtins.listToAttrs (
    builtins.map (system: {
      name = system;
      value = builtins.listToAttrs (
        builtins.map (rigName: {
          name = rigName;
          value =
            let
              rigDef = rigupToml.rigs.${rigName};

              # Resolve module references to actual paths
              resolvedModules = builtins.map resolveModuleRef rigDef.modules;

              # Convert TOML config to inline module
              configModule = if rigDef ? config then rigDef.config else { };

              # Build the rig
              pkgs = import inputs.nixpkgs { inherit system; };
            in
            rigupLib.buildRig {
              inherit pkgs;
              name = rigName;
              modules = resolvedModules ++ [ configModule ];
            };
        }) (builtins.attrNames rigupToml.rigs)
      );
    }) systems
  );
in
{
  inherit riglets rigs;
}
