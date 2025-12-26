# rigup flake's self
flake:
# Evaluate a rig from a set of riglet modules
# Returns an attrset with:
#   - toolRoot: combined tools' bin/, lib/, share/, etc. folders (via symlinks)
#   - configRoot: combined tools' XDG_CONFIG_HOME (via symlinks)
#   - docAttrs: attrset of riglet name -> doc folder derivation
#   - docRoot: combined riglet docs, one subfolder per riglet (via symlinks)
#   - meta: attrset of riglet name -> metadata
#   - home: complete rig directory (RIG.md + bin/ + docs/ + .config/)
#   - shell: complete rig, in devShell form (slightly different manifest
#            to directly read from nix store instead of local symlinks)
#   - extend: function that takes a list of extra riglets and combines them
#             with those of the rig
{
  modules,
  pkgs,
  name ? "agent-rig",
}:
with pkgs.lib;
let
  riglib = flake.lib.mkRiglib pkgs;

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
      flake.lib.rigletSchema
    ]
    ++ modules;
  };

  # Normalize a tool item: if it's a path, wrap it; otherwise return as-is
  normalizeTool = tool: if builtins.isPath tool then riglib.wrapScriptPath tool else tool;

  # Combined tools from all riglets
  toolRoot = pkgs.buildEnv {
    name = "${name}-tools";
    paths = flatten (
      mapAttrsToList (_: riglet: map normalizeTool riglet.tools) evaluated.config.riglets
    );
  };

  # Docs per riglet
  docAttrs = mapAttrs (_: riglet: riglet.docs) evaluated.config.riglets;

  # Metadata per riglet
  meta = mapAttrs (_: riglet: riglet.meta) evaluated.config.riglets;

  # XDG_CONFIG_HOME folder
  configRoot = pkgs.symlinkJoin {
    name = "${name}-config";
    paths = map (riglet: riglet.config-files) (attrValues evaluated.config.riglets);
  };

  # Docs folder (with symlinks to docs for all riglets)
  docRoot = pkgs.runCommand "${name}-docs" { } ''
    mkdir -p $out
    ${concatStringsSep "\n" (
      mapAttrsToList (
        rigletName: rigletDocs:
        optionalString (rigletDocs != null) ''
          ln -sL ${rigletDocs} $out/${rigletName}
        ''
      ) docAttrs
    )}
  '';

  # Generate RIG.md manifest from metadata and docs
  genManifest =
    args:
    flake.lib.genManifest (
      {
        inherit
          name
          meta
          docRoot
          pkgs
          ;
      }
      // args
    );

  # Complete agent home directory
  home = pkgs.runCommand "${name}-home" { } ''
    mkdir -p $out

    # Symlink tools
    ln -s ${toolRoot} $out/.local

    # Symlink config
    ln -s ${configRoot} $out/.config

    # Symlink docs
    ln -s ${docRoot} $out/docs

    cat > $out/activate.sh <<EOF
    export PATH="$out/.local/bin:\$PATH"
    export XDG_CONFIG_HOME="$out/.config"
    EOF

    # Add RIG.md manifest at top level
    # The manifest will mention tools and docs by relative path for brevity
    ln -s ${
      genManifest {
        shownDocRoot = "./docs";
        shownToolRoot = "./.local";
        shownActivationScript = "./activate.sh";
      }
    } $out/RIG.md
  '';

  # Development shell with rig environment
  shell = pkgs.mkShell {
    name = "${name}-shell";

    # Packages available in the shell. Sets PATH
    packages = [ toolRoot ];

    # Other environment variables
    XDG_CONFIG_HOME = configRoot;
    RIG_DOCS = docRoot;
    RIG_TOOLS = toolRoot;
    # The manifest will elude tools and docs full paths via env vars for brevity
    RIG_MANIFEST = genManifest {
      shownDocRoot = "$RIG_DOCS";
      shownToolRoot = "$RIG_TOOLS";
    };

    # Runs when entering the shell
    shellHook =
      let
        green = "\\033[0;32m";
        blue = "\\033[0;34m";
        yellow = "\\033[0;33m";
        reset = "\\033[0m";
      in
      ''
        if [ -z "$RIGUP_NO_BANNER" ]; then
        printf "${green}⬤━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━⬤\n\n"
        echo "                    ───    ╭─╮ ╶┬╴ ╭─╮   ╷ ╷ ┌┬╮    ───"
        echo "                    ──     ├┼╯ │ │ ├ ┬ : │││ ├─╯     ──"
        echo "                    ───    ╵╰─ ╶┴╴ ╰─╯   ╰─╯ ╵      ───"
        printf "${reset}\n"
        printf "  ${blue}Now in environment for rig \"${name}\".${reset}\n"
        printf "  ${yellow}\$RIG_MANIFEST${reset} contains the path of the ${green}RIG.md${reset} that your agent shoud\n"
        printf "  read first and foremost.\n"
        printf "  ${yellow}\$PATH${reset} exposes the rig tools.\n\n"
        printf "  ${blue}Other env vars set:${reset}\n"
        printf "  ${yellow}XDG_CONFIG_HOME${reset}=\"$XDG_CONFIG_HOME\"\n"
        printf "  ${yellow}RIG_DOCS${reset}=\"$RIG_DOCS\"\n"
        printf "  ${yellow}RIG_TOOLS${reset}=\"$RIG_TOOLS\"\n\n"
        printf "${green}⬤━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━⬤${reset}\n"
        fi
      '';
  };

  extend =
    extraModules:
    flake.lib.buildRig {
      inherit pkgs name;
      modules = modules ++ extraModules;
    };
in
{
  inherit
    toolRoot
    configRoot
    docAttrs
    docRoot
    meta
    home
    shell
    extend
    ;
}
