{ ... }:
let
  # Convert nested attribute set to directory tree of text files
  # Usage: writeDocsTree { files = { SKILL = "..."; references.foo = "..."; }; ... }
  # Creates: derivation with SKILL.md and references/foo.md
  writeDocsTree =
    {
      pkgs,
      files, # Nested attrset where leaves are strings
      ext ? ".md", # Extension to append to leaf paths
    }:
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
            in
            if lib.isAttrs value then
              mkFileCommands path value # Recurse into nested attrs
            else
              ''
                mkdir -p "$out/$(dirname "${path}${ext}")"
                cat > "$out/${path}${ext}" <<'EOF'
                ${value}
                EOF
              ''
          ) attrs
        );
    in
    pkgs.runCommand "docs" { } (mkFileCommands "" files);

  # Evaluate a rig from a set of riglet modules
  # Returns an attrset with:
  #   - env: combined buildEnv of all tools
  #   - docs: attrset of riglet name -> docs derivation
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
        writeDocsTree = args: writeDocsTree (args // { inherit pkgs; });
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
    in
    {
      inherit env docs;

      # Complete agent home directory with bin/ and docs/
      home = pkgs.runCommand "${name}-home" { } ''
        mkdir -p $out

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
      '';
    };
in
{
  inherit writeDocsTree buildRig;
}
