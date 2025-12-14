{ ... }:
let
  # Convert nested attribute set to directory tree of files
  # Usage: writeFileTree pkgs { "SKILL.md" = "..."; references."foo.md" = "..."; }
  # Creates: derivation with SKILL.md and references/foo.md
  # Leaves can be either strings (file content) or derivations (existing files)
  writeFileTree =
    pkgs: tree:
    let
      lib = pkgs.lib;

      # Recursively build file creation commands
      mkFileCommands =
        prefix: attrs:
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: value:
            let
              path = if prefix == "" then name else "${prefix}/${name}";
              delimiter = "NIXEOF_${builtins.hashString "sha256" path}";
            in
            if lib.isAttrs value && !lib.isDerivation value then
              mkFileCommands path value # Recurse into nested attrs
            else if lib.isDerivation value then
              # Symlink derivation to output path
              ''
                mkdir -p "$out/$(dirname "${path}")"
                ln -s ${value} "$out/${path}"
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

  # Evaluate a rig from a set of riglet modules
  # Returns an attrset with:
  #   - env: combined buildEnv of all tools
  #   - docs: attrset of riglet name -> docs derivation
  #   - meta: attrset of riglet name -> metadata
  #   - home: complete agent directory (bin/ + docs/)
  buildRig =
    {
      modules,
      pkgs,
      name ? "agent-rig",
    }:
    let
      lib = pkgs.lib;

      # Helpers available to riglets, with pkgs already bound
      riglib = {
        writeFileTree = writeFileTree pkgs;
        # Future helpers can be added here
      };

      # Evaluate the module system with all riglet modules
      evaluated = lib.evalModules {
        modules = modules ++ [
          ./rigletSchema.nix
        ];
        # Pass pkgs and riglib helpers to all modules
        specialArgs = {
          inherit pkgs riglib;
        };
      };
      # Combined tools from all riglets
      env = pkgs.buildEnv {
        inherit name;
        paths = lib.flatten (lib.mapAttrsToList (_: riglet: riglet.tools) evaluated.config.riglets);
      };

      # Docs per riglet
      docs = lib.mapAttrs (_: riglet: riglet.docs) evaluated.config.riglets;

      # Metadata per riglet
      meta = lib.mapAttrs (_: riglet: riglet.meta) evaluated.config.riglets;

      # Generate RIG.md manifest from metadata
      rigletsManifest = pkgs.writeText "RIG.md" ''
        # Available Riglets

        This rig provides the following riglets with their tools and documentation.

        <riglets_system>

        ## How to Use

        **Access documentation:**
        - Location: `docs/<riglet-name>/SKILL.md`
        - Read main docs: `cat docs/<riglet-name>/SKILL.md`
        - Read references: `cat docs/<riglet-name>/references/<topic>.md`

        **Use the tools:**
        - All tools are available in `bin/`
        - Add to PATH: `export PATH="$PWD/bin:$PATH"`

        ## Available Riglets

        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (rigletName: rigletMeta: ''
            <riglet>
            <name>${rigletName}</name>
            <title>${rigletMeta.name}</title>
            <description>${rigletMeta.description}</description>
            <whenToUse>
            ${lib.concatStringsSep "\n" (map (use: "- ${use}") rigletMeta.whenToUse)}
            </whenToUse>
            <keywords>${lib.concatStringsSep ", " rigletMeta.keywords}</keywords>
            <docs>docs/${rigletName}/</docs>
            </riglet>
          '') meta
        )}

        </riglets_system>
      '';
    in
    {
      inherit env docs meta;

      # Complete agent home directory with bin/ and docs/
      home = pkgs.runCommand "${name}-home" { } ''
        mkdir -p $out

        # Add RIG.md manifest at top level
        cp ${rigletsManifest} $out/RIG.md

        # Symlink all tools to bin/ (if env has a bin directory)
        if [ -d ${env}/bin ]; then
          ln -s ${env}/bin $out/bin
        fi

        # Create docs/ with subdirs per riglet
        mkdir -p $out/docs
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (rigletName: rigletDocs: ''
            ln -s ${rigletDocs} $out/docs/${rigletName}
          '') docs
        )}

        # Create .config/ with config files from all riglets
        mkdir -p $out/.config
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            _: riglet:
            lib.optionalString (riglet.config-files != null) ''
              cp -r ${riglet.config-files}/* $out/.config/
            ''
          ) evaluated.config.riglets
        )}
      '';
    };
in
{
  inherit writeFileTree buildRig;
}
