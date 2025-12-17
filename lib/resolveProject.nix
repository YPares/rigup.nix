selfLib:
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
  # Riglets can be either:
  #   - Plain modules: { config, pkgs, ... }: { ... }
  #   - Self-aware modules: self: { config, pkgs, ... }: { ... }
  # Self-aware modules receive the defining flake's `self`, allowing access to
  # `self.inputs.*` for external deps and `self.riglets.*` for inter-riglet imports.
  rigletsDir = inputs.self + "/riglets";
  rigletsDirEntries = if pathExists rigletsDir then readDir rigletsDir else { };

  # All riglets MUST be self-aware: self: { config, pkgs, ... }: { ... }
  # The first argument receives the defining flake's `self`, giving access to:
  #   - `self.inputs.*` for external package dependencies
  #   - `self.riglets.*` for inter-riglet imports (ensures deduplication)
  # Riglets that don't need `self` should use `_:` to ignore it.
  #
  # Each riglet is wrapped with a unique `key` for evalModules deduplication.
  # This ensures that if riglet A imports riglet B, and B is also added explicitly,
  # evalModules only processes B once.
  applyFlakeSelf =
    name: path:
    let
      module = (import path) inputs.self;
    in
    {
      # Include flake outPath in key to avoid collisions across flakes
      key = "riglet:${inputs.self.outPath}:${name}";
      imports = [ module ];
    };

  riglets = listToAttrs (
    map
      (
        filename:
        let
          # .nix files: strip extension; directories: keep as-is
          name = replaceStrings [ ".nix" ] [ "" ] filename;
        in
        {
          inherit name;
          value = applyFlakeSelf name (rigletsDir + "/${filename}");
        }
      )
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
      selfLib.buildRig {
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
