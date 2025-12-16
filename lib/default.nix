{ ... }:
let
  # Convert nested attribute set to directory tree of files
  # Usage: writeFileTree pkgs { "SKILL.md" = "..."; references."foo.md" = "..."; }
  # Creates: derivation with SKILL.md and references/foo.md
  # Leaves can be either strings (file content) or derivations (existing files)
  writeFileTree =
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
    pkgs.runCommand "file-tree" { } (mkFileCommands "" tree);

  # Evaluate a rig from a set of riglet modules
  # Returns an attrset with:
  #   - env: combined buildEnv of all tools
  #   - docs: attrset of riglet name -> docs derivation
  #   - meta: attrset of riglet name -> metadata
  #   - home: complete rig directory (RIG.toml + bin/ + [lib/ + share/ + ...] + docs/)
  buildRig =
    {
      modules,
      pkgs,
      name ? "agent-rig",
    }:
    with pkgs.lib;
    let
      # Helpers available to riglets, with pkgs already bound
      riglib = {
        writeFileTree = writeFileTree pkgs;
        # Future helpers can be added here
      };
      manifestLib = import ./manifest.nix { inherit pkgs; };

      # Evaluate the module system with all riglet modules
      evaluated = evalModules {
        modules = [
          {
            # Pass pkgs and riglib to all modules
            _module.args = {
              inherit pkgs riglib;
            };
          }
          ./rigletSchema.nix
        ]
        ++ modules;
      };

      # Combined tools from all riglets
      env = pkgs.buildEnv {
        inherit name;
        paths = flatten (mapAttrsToList (_: riglet: riglet.tools) evaluated.config.riglets);
      };

      # Docs per riglet
      docs = mapAttrs (_: riglet: riglet.docs) evaluated.config.riglets;

      # Metadata per riglet
      meta = mapAttrs (_: riglet: riglet.meta) evaluated.config.riglets;

      # Generate RIG.md manifest from metadata and docs
      manifest = manifestLib.generateManifest {
        inherit
          name
          meta
          docs
          pkgs
          ;
      };
    in
    {
      inherit env docs meta;

      # Complete agent home directory
      home = pkgs.runCommand "${name}-home" { } ''
        mkdir -p $out

        # Add RIG.md manifest at top level
        ln -sL ${manifest} $out/RIG.md

        # Symlink all env subfolders (notably bin/)
        for f in ${env}/*; do
          ln -sL "$f" $out/
        done

        # Create docs/ with subdirs per riglet
        mkdir -p $out/docs
        ${concatStringsSep "\n" (
          mapAttrsToList (rigletName: rigletDocs: ''
            ln -sL ${rigletDocs} $out/docs/${rigletName}
          '') docs
        )}

        # Create .config/ with config files from all riglets
        mkdir -p $out/.config
        ${concatStringsSep "\n" (
          mapAttrsToList (
            _: riglet:
            optionalString (riglet.config-files != null) ''
              for f in ${riglet.config-files}/*; do
                ln -sL "$f" $out/.config/
              done
            ''
          ) evaluated.config.riglets
        )}
      '';
    };

  resolveProject = import ./resolveProject.nix { inherit rigupLib; };

  rigupLib = {
    inherit writeFileTree buildRig resolveProject;
  };
in
rigupLib
