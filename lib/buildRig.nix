# rigup flake's self
flake:
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
  env = pkgs.buildEnv {
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
  config = pkgs.runCommand "${name}-config" { } ''
    mkdir -p $out
    ${concatStringsSep "\n" (
      mapAttrsToList (
        _: riglet:
        optionalString (riglet.config-files != null) ''
          for f in ${riglet.config-files}/*; do
            ln -sL "$f" $out/
          done
        ''
      ) evaluated.config.riglets
    )}
  '';

  # Docs folder (with symlinks to docs for all riglets)
  docs = pkgs.runCommand "${name}-docs" { } ''
    mkdir -p $out
    ${concatStringsSep "\n" (
      mapAttrsToList (rigletName: rigletDocs: ''
        ln -sL ${rigletDocs} $out/${rigletName}
      '') docAttrs
    )}
  '';

  # Generate RIG.md manifest from metadata and docs
  genManifest =
    mode:
    flake.lib.genManifest {
      inherit
        name
        meta
        docAttrs
        pkgs
        mode
        ;
    };

  # Complete agent home directory
  home = pkgs.runCommand "${name}-home" { } ''
    mkdir -p $out

    # Add RIG.md manifest at top level
    ln -s ${genManifest "home"} $out/RIG.md

    # Symlink env tools
    ln -s ${env} $out/.local

    # Symlink config
    ln -s ${config} $out/.config

    # Symlink docs
    ln -s ${docs} $out/docs

    cat > $out/activate.sh <<EOF
    export PATH="$out/.local/bin:\$PATH"
    export RIG_MANIFEST="$out/RIG.md"
    export RIG_DOCS="$out/docs"
    export XDG_CONFIG_HOME="$out/.config"
    EOF
    chmod +x $out/activate.sh
  '';

  # Development shell with rig environment
  shell = pkgs.mkShell {
    name = "${name}-shell";

    # Packages available in the shell. Sets PATH
    packages = [ env ];

    # Other environment variables
    RIG_MANIFEST = genManifest "shell";
    RIG_DOCS = docs;
    RIG_TOOLS = env;
    XDG_CONFIG_HOME = config;

    # Runs when entering the shell
    shellHook =
      let
        green = "\\033[0;32m";
        blue = "\\033[0;34m";
        yellow = "\\033[0;33m";
        reset = "\\033[0m";
      in
      ''
        printf "${green}⬤━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━⬤\n\n"
        echo "                    ───    ╭─╮ ╶┬╴ ╭─╮   ╷ ╷ ┌┬╮    ───"
        echo "                    ──     ├┼╯ │ │ ├ ┬ : │││ ├─╯     ──"
        echo "                    ───    ╵╰─ ╶┴╴ ╰─╯   ╰─╯ ╵      ───"
        printf "${reset}\n"
        printf "  ${blue}Now in environment for rig \"${name}\".${reset}\n"
        printf "  ${yellow}\$PATH${reset} exposes the rig tools.\n"
        printf "  ${yellow}\$RIG_MANIFEST${reset} contains the path of the ${green}RIG.md${reset} that your agent shoud\n"
        printf "  read first and foremost.\n\n"
        printf "  ${blue}Other env vars set:${reset}\n"
        printf "  ${yellow}RIG_DOCS${reset}=\"$RIG_DOCS\"\n"
        printf "  ${yellow}RIG_TOOLS${reset}=\"$RIG_TOOLS\"\n"
        printf "  ${yellow}XDG_CONFIG_HOME${reset}=\"$XDG_CONFIG_HOME\"\n\n"
        printf "${green}⬤━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━⬤${reset}\n"
      '';
  };
in
{
  inherit
    env
    config
    docAttrs
    docs
    meta
    home
    shell
    ;
}
