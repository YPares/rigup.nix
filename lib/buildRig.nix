# rigup flake's self
flake:
# Evaluate a rig from a set of riglet modules
# Returns an attrset with:
#   - name: the rig name
#   - toolRoot: combined tools' bin/, lib/, share/, etc. folders (via symlinks)
#   - configRoot: combined tools' XDG_CONFIG_HOME (via symlinks)
#   - docAttrs: attrset of riglet name -> doc folder derivation
#   - docRoot: combined riglet docs, one subfolder per riglet (via symlinks)
#   - meta: attrset of riglet name -> metadata
#   - home: complete rig directory (RIG.md + bin/ + docs/ + .config/)
#   - shell: complete rig, in devShell form (slightly different manifest
#            to directly read from nix store instead of local symlinks)
#   - extend: function that takes a list of extra riglet modules and combines them
#             with those of the rig
#   - entrypoint: null, or folder derivation with `bin/<entrypoint_executable>`
{
  modules,
  pkgs,
  name ? "agent-rig",
}:
with pkgs.lib;
let
  # Create the riglib attrset of helper functions, so it can be used by riglets
  riglib = flake.lib.mkRiglib {
    inherit pkgs;
  };

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

  # Extract the executable name from a tool (without IFD, using eval-time metadata)
  getToolExecutableName =
    tool:
    with builtins;
    if isPath tool then
      # For script paths, extract basename
      baseNameOf (toString tool)
    else
    # For packages, extract the main program name from metadata
    if tool ? meta.mainProgram then
      tool.meta.mainProgram
    else if tool ? pname then
      tool.pname
    else
      # Fallback: parse the name attribute
      (parseDrvName tool.name).name;

  # Combined tools from all riglets
  toolRoot = pkgs.buildEnv {
    name = "${name}-tools";
    paths = flatten (
      mapAttrsToList (_: riglet: map normalizeTool riglet.tools) evaluated.config.riglets
    );
  };

  # Docs per riglet
  docAttrs = mapAttrs (_: riglet: riglet.docs) evaluated.config.riglets;

  # Metadata per riglet, enriched with computed command names
  meta = mapAttrs (
    rigletName: riglet:
    riglet.meta
    // {
      # Add computed command names to each riglet's metadata
      commandNames = map getToolExecutableName riglet.tools;
    }
  ) evaluated.config.riglets;

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

  # Generate a RIG.md manifest file from riglet metadata and docs
  # See lib/genManifest.nix for full documentation
  # Argument already set: pkgs, name, meta, docRoot
  # Optional extra args: shownDocRoot, shownToolRoot, shownActivationScript
  genManifest =
    args:
    flake.lib.genManifest (
      {
        inherit
          pkgs
          name
          meta
          toolRoot
          docRoot
          configRoot
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
        shownActivationScript = "./activate.sh";
        shownDocRoot = "./docs";
        shownToolRoot = "./.local";
        shownConfigRoot = "./.config";
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
    # The manifest will elude docs full paths via env var for brevity
    RIG_MANIFEST = genManifest {
      shownDocRoot = "$RIG_DOCS";
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
        echo ""
        printf "${green}⬤━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━⬤${reset}\n"
        fi
      '';
  };

  extend =
    {
      newName ? name,
      extraModules ? [ ],
    }:
    flake.lib.buildRig {
      inherit pkgs;
      name = newName;
      modules = modules ++ extraModules;
    };

  # Build the base rig attrset (without entrypoint and extend to avoid circularity)
  baseRig = {
    inherit
      name
      toolRoot
      configRoot
      docAttrs
      docRoot
      meta
      home
      shell
      genManifest
      ;
  };
in
baseRig
// optionalAttrs (evaluated.config.entrypoint != null) {
  entrypoint = evaluated.config.entrypoint baseRig;
}
// {
  inherit extend;
}
