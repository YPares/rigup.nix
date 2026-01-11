# rigup flake's self
flake:
# Resolves complete project structure from rigup.toml file(s) and riglets folder.
# Mandatory arguments are 'inputs' and 'projectUri'.
#
# Arguments:
#   - projectUri: a URI indentifying your project, to be used in error messages
#   - inputs: flake inputs attrset (must include self and nixpkgs)
#   - systems: list of systems to generate rigs for (e.g., ["x86_64-linux"])
#   - rigletsDir: directory where to look for riglets
#   - tomlConfigs: path to rigup.toml(s) files
#   - checkRiglets: if true, a singleton rig for each riglet will be built as part of checks.${system}
#   - checkRigs: if true, all rigs' derivations will be included into checks.${system}
#
# Returns: { riglets = {...}; rigs.<system>.<rig> = {...}; [ checks.<system>."<rig>-{home,shell}" = <derivation> ] }
{
  projectUri,
  inputs,
  systems ? inputs.nixpkgs.lib.systems.flakeExposed,
  rigletsDir ? "${inputs.self}/riglets",
  tomlConfigs ? [
    "${inputs.self}/rigup.toml"
    "${inputs.self}/rigup.local.toml"
  ],
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

  # Tidy up some paths for error message purposes
  tryRmStorePrefix =
    absPath:
    let
      matches = builtins.match "^${builtins.storeDir}/[^/]+/(.+)$" (toString absPath);
    in
    if matches == null then absPath else builtins.head matches;

  # Each riglet takes self as a first argument, and is wrapped by creating a dummy module whose sole purpose is to import the riglet and define a unique `key` for evalModules deduplication.
  # This ensures that if riglet A imports riglet B, and B is also added explicitly,
  # evalModules only processes B once.
  applyRigletFirstArg = rigletAbsPath: {
    # To deduplicate if the same riglet is added twice to the rig
    key = rigletAbsPath;
    # For error messages (shows path relative to projectUri & full path in Nix store)
    _file = "${projectUri}/${tryRmStorePrefix rigletAbsPath} (${rigletAbsPath})";
    # Pass enhanced inputs so riglets can access claudeMarketplace
    imports = [ (import rigletAbsPath enhancedInputs.self) ];
  };

  riglets = concatMapAttrs (
    fileName: entry:
    optionalAttrs
      (
        (match ".*\\.nix$" fileName != null && fileName != "default.nix")
        || (entry == "directory" && pathExists "${rigletsDir}/${fileName}/default.nix")
      )
      (
        let
          # .nix files: strip extension; directories: keep as-is
          rigletName = replaceStrings [ ".nix" ] [ "" ] fileName;
          rigletRelPath = if entry == "directory" then "${fileName}/default.nix" else fileName;
        in
        {
          "${rigletName}" = applyRigletFirstArg "${rigletsDir}/${rigletRelPath}";
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
          inherit source;
          extends = { };
          riglets = { };
          config = {
            key = "${source}::${rigName}";
            _file = # Will be shown in error messages
              "${projectUri}/${tryRmStorePrefix source}::[rigs.${rigName}.config] (${source})";
          };
        } rigDef
      ) contents.rigs or { };
    };

  ensureList = x: if isList x then x else [ x ];

  extendsSpecToRigs =
    system: rigDefError: extendsSpec:
    concatLists (
      mapAttrsToList (
        input: namesFromInputs:
        map (
          baseRigName:
          enhancedInputs.${input}.rigs.${system}.${baseRigName}
            or (throw (rigDefError "extends `${input}.rigs.${system}.${baseRigName}` which does not exist"))
        ) (ensureList namesFromInputs)
      ) extendsSpec
    );

  # Resolve riglets from the TOML structure
  # Takes riglets attrset from TOML: { self = ["riglet1", ...]; input = ["riglet2", ...]; }
  # Returns list of resolved modules
  rigletsSpecToModules =
    rigDefError: rigletsSpec:
    concatLists (
      mapAttrsToList (
        input: namesFromInputs:
        map (
          rigletName:
          enhancedInputs.${input}.riglets.${rigletName}
            or (throw (rigDefError "uses `${input}.riglets.${rigletName}` which does not exist"))
        ) (ensureList namesFromInputs)
      ) rigletsSpec
    );

  tomlContentsToRig =
    system: rigName: rigDef:
    let
      pkgs = import inputs.nixpkgs { inherit system; };
      rigDefError =
        msg:
        "${projectUri}/${tryRmStorePrefix rigDef.source}::[rigs.${rigName}] ${msg}\n(source: ${rigDef.source})";
    in
    flake.lib.buildRig {
      inherit pkgs;
      name = rigName;
      modules =
        concatMap (r: r.modules) (extendsSpecToRigs system rigDefError rigDef.extends)
        ++ rigletsSpecToModules rigDefError rigDef.riglets
        ++ [ rigDef.config ];
    };

  # Build rigs for all systems
  rigs = genAttrs systems (
    system:
    let
      loadedConfigs = map loadTomlConfig tomlConfigs;
      mergeRigDefs =
        rigName: rigDefs:
        let
          sources = concatStringsSep "\n" (map (d: " - ${tryRmStorePrefix d.source} (${d.source})") rigDefs);
        in
        if length rigDefs > 1 then
          throw "In ${projectUri}: rig `${rigName}` is defined in several files:\n${sources}\nTo override some rig's config in another TOML file, define a new rig that extends it."
        else
          head rigDefs;
    in
    mapAttrs (tomlContentsToRig system) (
      attrsets.zipAttrsWith mergeRigDefs (map (c: c.rigs) loadedConfigs)
    )
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
