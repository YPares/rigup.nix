# rigup flake's self
flake:
{
  pkgs, # From nixpkgs
}:
let
  options = {
    # Make a boolean option, false by default
    # DEPRECATED: use pkgs.lib.mkEnableOption instead
    flag =
      description:
      pkgs.lib.warn "riglib.options.flag is deprecated, use pkgs.lib.mkEnableOption instead" (
        with pkgs.lib;
        mkOption {
          inherit description;
          type = types.bool;
          default = false;
        }
      );
  };

  # Override a derivation so it is always built locally, and not queried from remote substituters
  alwaysLocal =
    x:
    if pkgs.lib.isDerivation x then
      x
      // {
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
    else
      x;

  # Convert nested attribute set to directory tree of files
  # Usage: writeFileTree pkgs { "SKILL.md" = "..."; references."foo.md" = "..."; }
  # Creates: derivation with SKILL.md and references/foo.md
  # Leaves can be either strings (file content), paths, or derivations (existing files)
  writeFileTree =
    tree:
    with pkgs.lib;
    let
      # Recursively build file creation commands
      mkFileCommands =
        prefix: attrs:
        concatStringsSep "\n" (
          mapAttrsToList (
            name: value:
            let
              filepath = if prefix == "" then name else "${prefix}/${name}";
              delimiter = "NIXEOF_${builtins.hashString "sha256" filepath}";
            in
            if isAttrs value && !isDerivation value then
              mkFileCommands filepath value # Recurse into nested attrs
            else if strings.hasPrefix builtins.storeDir value then
              # If 'value' is some string-convertible path into the Nix store,
              # symlink to output path
              ''
                mkdir -p "$out/$(dirname "${filepath}")"
                ln -sL ${value} "$out/${filepath}"
              ''
            else
              # Write string content to file
              ''
                mkdir -p "$out/$(dirname "${filepath}")"
                cat > "$out/${filepath}" <<'${delimiter}'
                ${value}
                ${delimiter}
              ''
          ) attrs
        );
    in
    pkgs.runCommandLocal "file-tree" { } (mkFileCommands "" tree);

  # Convert a script path to a package by wrapping it with writeShellScriptBin
  # Derives the executable name from the script's filename (without extension)
  wrapScriptPath =
    scriptPath:
    let
      scriptName = baseNameOf (toString scriptPath);
    in
    alwaysLocal (pkgs.writeShellScriptBin scriptName (builtins.readFile scriptPath));

  # Convert all files in a folder to a list of wrapped script packages
  #
  # Usage: tools = [ x y z ] ++ riglib.useScriptFolder ./scripts
  # Returns a list where each file is wrapped via wrapScriptPath
  useScriptFolder =
    folderPath:
    with pkgs.lib;
    let
      # Read directory contents - returns attrset { filename = "regular" | "directory" | ... }
      dirContents = builtins.readDir folderPath;
      # Filter to only regular files (exclude directories, symlinks, etc.)
      files = filterAttrs (name: type: type == "regular") dirContents;
      # Convert each file to absolute path
      scriptPaths = mapAttrsToList (name: _type: folderPath + "/${name}") files;
    in
    # Wrap each script path into a package
    map wrapScriptPath scriptPaths;

  # Recursively filter a directory to keep only files with specified extensions
  #
  # Usage: riglib.filterFileTree ["md" "txt"] ./some/dir
  # Creates: derivation containing only .md and .txt files (preserving directory structure)
  # Extensions can be specified with or without leading dots, and are treated in a case-insentitive manner
  #
  # For more complicating filtering, use nixpkgs.lib.fileset
  filterFileTree =
    extensions: rootPath:
    with pkgs.lib;
    let
      # Normalize extensions to lowercase without leading dots
      normalizedExts = map (ext: toLower (removePrefix "." ext)) extensions;

      # Check if a filename has one of the allowed extensions
      hasAllowedExt = filename: any (ext: hasSuffix ext (toLower filename)) normalizedExts;
    in
    alwaysLocal (cleanSourceWith {
      src = rootPath;
      filter = filepath: type: type == "directory" || hasAllowedExt filepath;
    });

  # Wrap a set of tools to fix a specific set of environment variables for them
  wrapWithEnv =
    {
      name,
      tools,
      env,
    }:
    with pkgs.lib;
    alwaysLocal (
      pkgs.symlinkJoin {
        inherit name;
        paths = tools;
        buildInputs = [ pkgs.makeBinaryWrapper ];
        postBuild =
          let
            setFlagsList = concatMap (
              { name, value }:
              [
                "--set"
                name
                value
              ]
            ) (attrsToList env);
          in
          ''
            for prg in $out/bin/*; do
              wrapProgram "$prg" ${escapeShellArgs setFlagsList}
            done
          '';
      }
    );

  # Render a minijinja template
  renderMinijinja =
    {
      template, # Path. File to use as template
      data, # (Nested) attrset. Data to fill in the template
      strict ? true, # Fail if the template mentions variables which aren't present in 'data'
    }:
    with pkgs.lib;
    pkgs.runCommandLocal (baseNameOf template) { } ''
      ${getExe pkgs.minijinja} ${optionalString strict "--strict"} ${template} ${toJSON data} --format json --output $out
    '';

  # Format a (nested) Nix attrset to a JSON, TOML, YAML or XML file.
  # Forces local build and disallows remote substituters so no time is spent querying
  formatLocal =
    {
      format,
      name ? "local.${format}",
      opts ? { },
    }:
    attrset:
    let
      formatter =
        pkgs.formats.${format} or (throw "riglib.formatLocal: format '${format}' not supported");
    in
    alwaysLocal ((formatter opts).generate name attrset);
  # Generate a JSON file from a Nix attrset. See formatLocal
  toJSON = formatLocal { format = "json"; };
  # Generate a TOML file from a Nix attrset. See formatLocal
  toTOML = formatLocal { format = "toml"; };
  # Generate a YAML file from a Nix attrset. See formatLocal
  toYAML = formatLocal { format = "yaml"; };
  # Generate an XML file without header from a Nix attrset. See formatLocal
  toXML = formatLocal {
    format = "xml";
    opts.withHeader = false;
  };
in
# Helper functions to use for riglet declarations
{
  inherit
    options
    alwaysLocal
    writeFileTree
    wrapScriptPath
    useScriptFolder
    filterFileTree
    wrapWithEnv
    renderMinijinja
    formatLocal
    toJSON
    toTOML
    toYAML
    toXML
    ;
}
