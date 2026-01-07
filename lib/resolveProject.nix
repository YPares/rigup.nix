# rigup flake's self
flake:
# Resolves complete project structure from rigup.toml configuration
# Arguments:
#   - projectUri: a URI indentifying your project, to be used in error messages
#   - inputs: flake inputs attrset (must include self and nixpkgs)
#   - systems: list of systems to generate rigs for (e.g., ["x86_64-linux"])
#   - checkRiglets: if true, a singleton rig for each riglet will be built as part of checks.${system}
#   - checkRigs: if true, all rigs' derivations will be included into checks.${system}
# Returns: { riglets = {...}; rigs.<system>.<rig> = {...}; [ checks.<system>."<rig>-{home,shell}" = <derivation> ] }
{
  projectUri,
  inputs,
  systems ? inputs.nixpkgs.lib.systems.flakeExposed,
  checkRiglets ? false,
  checkRigs ? false,
}:
with inputs.nixpkgs.lib;
let
  # Enhance inputs with claudeMarketplace attributes where marketplace.json exists
  enhancedInputsBase = mapAttrs (
    _name: input:
    let
      claudePlugins = flake.lib.resolveClaudeMarketplace input;
    in
    input // optionalAttrs (claudePlugins != null) { inherit claudePlugins; }
  ) inputs;

  # Update self.inputs to point to the enhanced inputs (so riglets see them)
  enhancedInputs = enhancedInputsBase // {
    self = enhancedInputsBase.self // {
      inputs = enhancedInputsBase;
    };
  };

  # Auto-discover all riglets from riglets/ directory
  rigletsDir = enhancedInputs.self + "/riglets";

  # Each riglet takes self as a first argument, and is wrapped by creating a dummy module whose sole purpose is to import the riglet and define a unique `key` for evalModules deduplication.
  # This ensures that if riglet A imports riglet B, and B is also added explicitly,
  # evalModules only processes B once.
  applyFlakeSelf = rigletName: rigletPath: {
    # To deduplicate if the same riglet is added twice to the rig
    key = rigletPath;
    # For error messages - shows full path in Nix store
    _file = "${projectUri}#riglets.${rigletName} (${rigletPath})";
    # Pass enhanced inputs so riglets can access claudeMarketplace
    imports = [ (import rigletPath enhancedInputs.self) ];
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

  loadTomlConfig =
    source:
    let
      contents = if pathExists source then fromTOML (readFile source) else { };
    in
    {
      rigs = mapAttrs (
        rigName: rigDef:
        recursiveUpdate {
          riglets = { };
          config._file = "${projectUri}/${baseNameOf source}::[rigs.${rigName}.config] (${source})"; # Will be shown in error messages
        } rigDef
      ) contents.rigs or { };
    };

  # Resolve riglets from the TOML structure
  # Takes riglets attrset from TOML: { self = ["riglet1", ...]; input = ["riglet2", ...]; }
  # Returns list of resolved modules
  rigletsSpecToModules =
    source: rigName: rigletsSpec:
    concatLists (
      attrValues (
        mapAttrs (
          input: names:
          map (
            n:
            enhancedInputs.${input}.riglets.${n}
              or (throw "${projectUri}/${baseNameOf source}::[rigs.${rigName}] uses `${input}.riglets.${n}` which does not exist\n(source: ${source})")
          ) names
        ) rigletsSpec
      )
    );

  tomlContentsToRigs =
    system: source: rigName: rigDef:
    let
      pkgs = import inputs.nixpkgs { inherit system; };
      modules = rigletsSpecToModules source rigName rigDef.riglets ++ [ rigDef.config ];
    in
    if rigDef ? "extends" then
      let
        baseRigInputs = attrNames rigDef.extends;
        baseRigInput =
          if builtins.length baseRigInputs != 1 then
            throw "${projectUri}/${baseNameOf source}::[rigs.${rigName}] extends more than one base rig\n(source: ${source})"
          else
            builtins.head baseRigInputs;
        baseRigName = rigDef.extends.${baseRigInput};
      in
      (enhancedInputs.${baseRigInput}.rigs.${system}.${baseRigName}
        or (throw "${projectUri}/${baseNameOf source}::[rigs.${rigName}] extends `${baseRigInput}.rigs.${system}.${baseRigName}` which does not exist\n(source: ${source})")
      ).extend
        {
          newName = rigName;
          extraModules = modules;
        }
    else
      flake.lib.buildRig {
        inherit pkgs modules;
        name = rigName;
      };

  # Build rigs for all systems
  rigs = genAttrs systems (
    system:
    let
      toml = enhancedInputs.self + "/rigup.toml";
      localToml = enhancedInputs.self + "/rigup.local.toml";
    in
    mapAttrs (tomlContentsToRigs system toml) (loadTomlConfig toml).rigs
    // mapAttrs (tomlContentsToRigs system localToml) (loadTomlConfig localToml).rigs
  );

  rigChecks =
    prefix: rig:
    {
      "${prefix}${rig.name}-docs" = rig.docRoot;
      "${prefix}${rig.name}-tools" = rig.toolRoot;
      "${prefix}${rig.name}-config" = rig.configRoot;
      "${prefix}${rig.name}-manifest" = rig.manifest;
    }
    // optionalAttrs (rig ? entrypoint) {
      "${prefix}${rig.name}-entrypoint" = rig.entrypoint;
    };

  checkedRiglets = optionalAttrs checkRiglets (
    genAttrs systems (
      system:
      concatMapAttrs (
        name: riglet:
        rigChecks "riglets-" (
          flake.lib.buildRig {
            inherit name;
            modules = [ riglet ];
            pkgs = import inputs.nixpkgs { inherit system; };
          }
        )
      ) riglets
    )
  );

  checkedRigs = optionalAttrs checkRigs (
    genAttrs systems (system: concatMapAttrs (_name: rigChecks "rigs-") rigs.${system})
  );
in
{
  inherit riglets rigs;
}
// optionalAttrs (checkRiglets || checkRigs) {
  checks = recursiveUpdate checkedRiglets checkedRigs;
}
