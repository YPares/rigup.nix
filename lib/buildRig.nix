selfLib:
# Evaluate a rig from a set of riglet modules
# Returns an attrset with:
#   - env: combined buildEnv of all tools
#   - docs: attrset of riglet name -> docs derivation
#   - meta: attrset of riglet name -> metadata
#   - home: complete rig directory (RIG.md + bin/ + docs/ + .config/)
{
  modules,
  pkgs,
  name ? "agent-rig",
}:
with pkgs.lib;
let
  riglib = selfLib.mkRiglib pkgs;

  # Evaluate the module system with all riglet modules
  evaluated = evalModules {
    modules = [
      {
        # Pass pkgs, system and riglib to all modules
        _module.args = {
          inherit pkgs riglib;
          inherit (pkgs.stdenv.hostPlatform) system;
          # Helpers available to riglets, with pkgs already bound
        };
      }
      selfLib.rigletSchema
    ]
    ++ modules;
  };

  # Normalize a tool item: if it's a path, wrap it; otherwise return as-is
  normalizeTool = tool: if builtins.isPath tool then riglib.wrapScriptPath tool else tool;

  # Combined tools from all riglets
  env = pkgs.buildEnv {
    inherit name;
    paths = flatten (
      mapAttrsToList (_: riglet: map normalizeTool riglet.tools) evaluated.config.riglets
    );
  };

  # Docs per riglet
  docs = mapAttrs (_: riglet: riglet.docs) evaluated.config.riglets;

  # Metadata per riglet
  meta = mapAttrs (_: riglet: riglet.meta) evaluated.config.riglets;

  # Generate RIG.md manifest from metadata and docs
  manifest = selfLib.genManifest {
    inherit
      name
      meta
      docs
      pkgs
      ;
  };

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
in
{
  inherit
    env
    docs
    meta
    home
    ;
}
