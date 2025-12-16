rigupLib:
# Resolves complete project structure from rigup.toml configuration
# Arguments:
#   - inputs: flake inputs attrset (must include self and nixpkgs)
#   - systems: list of systems to generate rigs for (e.g., ["x86_64-linux"])
# Returns: { riglets = {...}; rigs.<system>.<rig> = {...}; }
{
  inputs,
  systems ? inputs.nixpkgs.lib.systems.flakeExposed,
}:
with builtins;
let
  inherit (inputs.nixpkgs.lib) genAttrs;

  # Auto-discover all riglets from riglets/ directory
  rigletsDir = inputs.self + "/riglets";
  rigletsDirEntries = if pathExists rigletsDir then readDir rigletsDir else { };
  riglets = listToAttrs (
    map
      (name: {
        # .nix files: strip extension
        name = replaceStrings [ ".nix" ] [ "" ] name;
        value = rigletsDir + "/${name}";
      })
      (
        filter (
          name:
          (match ".*\\.nix$" name != null && name != "default.nix")
          || (rigletsDirEntries.${name} == "directory" && pathExists (rigletsDir + "/${name}/default.nix"))
        ) (attrNames rigletsDirEntries)
      )
  );

  rigupTomlPath = inputs.self + "/rigup.toml";
  # Read rigup.toml from repository root if it exists
  rigupTomlContents = if pathExists rigupTomlPath then fromTOML (readFile rigupTomlPath) else { };

  # Resolve riglets from the TOML structure
  # Takes riglets attrset from TOML: { self = ["riglet1", ...]; input = ["riglet2", ...]; }
  # Returns list of resolved modules
  rigletsSpecToModules =
    rigletsSpec:
    concatLists (
      attrValues (mapAttrs (input: names: map (n: inputs.${input}.riglets.${n}) names) rigletsSpec)
    );

  # Build rigs for all systems
  rigs = genAttrs systems (
    system:
    mapAttrs (
      rigName: rigDef:
      let
        pkgs = import inputs.nixpkgs { inherit system; };
      in
      rigupLib.buildRig {
        inherit pkgs;
        name = rigName;
        modules = rigletsSpecToModules (rigDef.riglets or [ ]) ++ [ (rigDef.config or { }) ];
      }
    ) (rigupTomlContents.rigs or { })
  );
in
{
  inherit riglets rigs;
}
