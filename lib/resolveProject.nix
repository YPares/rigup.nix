# rigup flake's self
flake:
# Resolves complete project structure from rigup.toml configuration
# Arguments:
#   - inputs: flake inputs attrset (must include self and nixpkgs)
#   - systems: list of systems to generate rigs for (e.g., ["x86_64-linux"])
#   - checkRigs: if true, all rigs' home & shell derivations will be included into checks.${system}
# Returns: { riglets = {...}; rigs.<system>.<rig> = {...}; [ checks.<system>."<rig>-{home,shell}" = <derivation> ] }
{
  inputs,
  systems ? inputs.nixpkgs.lib.systems.flakeExposed,
  checkRigs ? false,
}:
with inputs.nixpkgs.lib;
let
  # Auto-discover all riglets from riglets/ directory
  rigletsDir = inputs.self + "/riglets";

  # Each riglet takes self as a first argument, and is wrapped by creating a dummy module whose sole purpose is to import the riglet and define a unique `key` for evalModules deduplication.
  # This ensures that if riglet A imports riglet B, and B is also added explicitly,
  # evalModules only processes B once.
  applyFlakeSelf = name: path: {
    # Include flake outPath in key to avoid collisions across flakes
    key = "riglet:${inputs.self}:${name}";
    # For error messages - shows full path in Nix store
    _file = path;
    imports = [ (import path inputs.self) ];
  };

  riglets = concatMapAttrs (
    fileName: entry:
    optionalAttrs
      (
        (match ".*\\.nix$" fileName != null && fileName != "default.nix")
        || (entry == "directory" && pathExists (rigletsDir + "/${fileName}/default.nix"))
      )
      (
        let
          # .nix files: strip extension; directories: keep as-is
          rigletName = replaceStrings [ ".nix" ] [ "" ] fileName;
          rigletPath =
            if entry == "directory" then
              rigletsDir + "/${fileName}/default.nix"
            else
              rigletsDir + "/${fileName}";
        in
        {
          "${rigletName}" = applyFlakeSelf rigletName rigletPath;
        }
      )
  ) (if pathExists rigletsDir then builtins.readDir rigletsDir else { });

  rigupTomlPath = inputs.self + "/rigup.toml";
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
      flake.lib.buildRig {
        inherit pkgs;
        name = rigName;
        modules = rigletsSpecToModules (rigDef.riglets or [ ]) ++ [ (rigDef.config or { }) ];
      }
    ) (rigupTomlContents.rigs or { })
  );

  checks = genAttrs systems (
    system:
    concatMapAttrs (name: rig: {
      "rigup-${name}-home" = rig.home;
      "rigup-${name}-shell" = rig.shell;
    }) rigs.${system}
  );
in
{
  inherit riglets rigs;
}
// (if checkRigs then { inherit checks; } else { })
