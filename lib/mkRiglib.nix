# rigup flake's self
_flake:
# Helper functions to use for riglet declarations
pkgs: rec {
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
              path = if prefix == "" then name else "${prefix}/${name}";
              delimiter = "NIXEOF_${builtins.hashString "sha256" path}";
            in
            if isAttrs value && !isDerivation value then
              mkFileCommands path value # Recurse into nested attrs
            else if isDerivation value || builtins.isPath value then
              # Symlink derivation or path to output path
              ''
                mkdir -p "$out/$(dirname "${path}")"
                ln -sL ${value} "$out/${path}"
              ''
            else
              # Write string content to file
              ''
                mkdir -p "$out/$(dirname "${path}")"
                cat > "$out/${path}" <<'${delimiter}'
                ${value}
                ${delimiter}
              ''
          ) attrs
        );
    in
    pkgs.runCommand "file-tree" { } (mkFileCommands "" tree);

  # Convert a script path to a package by wrapping it with writeShellScriptBin
  # Derives the executable name from the script's filename (without extension)
  wrapScriptPath =
    scriptPath:
    let
      scriptName = baseNameOf (toString scriptPath);
    in
    pkgs.writeShellScriptBin scriptName (builtins.readFile scriptPath);

  # Convert all files in a folder to a list of wrapped script packages
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
}
