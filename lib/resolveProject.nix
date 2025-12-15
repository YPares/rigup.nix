# Auto-discover riglets from riglets/ folder and resolve rigs from rigup.toml
{ rigupLib, ... }:

# Resolves complete project structure from rigup.toml configuration
# Arguments:
#   - inputs: flake inputs attrset (must include self and nixpkgs)
#   - systems: list of systems to generate rigs for (e.g., ["x86_64-linux"])
# Returns: { riglets = {...}; rigs.<system>.<rig> = {...}; }
{
  inputs,
  systems ? inputs.nixpkgs.lib.systems.flakeExposed,
}:
let
  rigupTomlPath = (inputs.self + "/rigup.toml");

  # Read rigup.toml from repository root if it exists
  rigupToml =
    if builtins.pathExists rigupTomlPath then
      builtins.fromTOML (builtins.readFile rigupTomlPath)
    else
      { };

  # Auto-discover all riglets from riglets/ directory
  rigletsDir = inputs.self + "/riglets";
  rigletEntries = if builtins.pathExists rigletsDir then builtins.readDir rigletsDir else { };

  # Find .nix files (excluding default.nix in root)
  nixFileRiglets = builtins.filter (
    name: builtins.match ".*\\.nix" name != null && name != "default.nix"
  ) (builtins.attrNames rigletEntries);

  # Find directories containing default.nix
  dirRiglets = builtins.filter (
    name:
    rigletEntries.${name} == "directory" && builtins.pathExists (rigletsDir + "/${name}/default.nix")
  ) (builtins.attrNames rigletEntries);

  # Combine both types into riglets attrset
  riglets = builtins.listToAttrs (
    # .nix files: strip extension
    (builtins.map (name: {
      name = builtins.replaceStrings [ ".nix" ] [ "" ] name;
      value = rigletsDir + "/${name}";
    }) nixFileRiglets)
    ++
      # directories: use directory name as-is
      (builtins.map (name: {
        name = name;
        value = rigletsDir + "/${name}";
      }) dirRiglets)
  );

  # Resolve riglets from the new TOML structure
  # Takes riglets attrset from TOML: { self = ["riglet1", ...]; input = ["riglet2", ...]; }
  # Returns list of resolved module paths
  resolveRiglets =
    rigletsSpec:
    builtins.concatLists (
      builtins.attrValues (
        builtins.mapAttrs (
          inputName: rigletNames:
          builtins.map (
            rigletName:
            if inputName == "self" then riglets.${rigletName} else inputs.${inputName}.riglets.${rigletName}
          ) rigletNames
        ) rigletsSpec
      )
    );

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

              # Resolve riglets from TOML spec to actual module paths
              resolvedModules = if rigDef ? riglets then resolveRiglets rigDef.riglets else [ ];

              # Convert TOML config to inline module
              configModule = if rigDef ? config then rigDef.config else { };

              # Build the rig
              pkgs = import inputs.nixpkgs { inherit system; };
            in
            rigupLib.buildRig {
              inherit pkgs inputs;
              name = rigName;
              modules = resolvedModules ++ [ configModule ];
            };
        }) (builtins.attrNames (rigupToml.rigs or { }))
      );
    }) systems
  );
in
{
  inherit riglets rigs;
}
