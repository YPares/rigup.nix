_selfLib:
# Convert nested attribute set to directory tree of files
# Usage: writeFileTree pkgs { "SKILL.md" = "..."; references."foo.md" = "..."; }
# Creates: derivation with SKILL.md and references/foo.md
# Leaves can be either strings (file content), paths, or derivations (existing files)
pkgs: tree:
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
pkgs.runCommand "file-tree" { } (mkFileCommands "" tree)
