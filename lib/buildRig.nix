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
#   - configOptions: serializable nested attrset of option name -> option info (description, type, default, value)
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
  rigName = name;

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
    name = "${rigName}-tools";
    paths = concatMap (riglet: map normalizeTool riglet.tools) (attrValues evaluated.config.riglets);
  };

  # Docs per riglet
  docAttrs = mapAttrs (_: riglet: riglet.docs) evaluated.config.riglets;

  # Metadata per riglet, enriched with computed command names
  rigMeta = mapAttrs (
    rigletName: riglet:
    riglet.meta
    // {
      # Add computed command names to each riglet's metadata
      commandNames = map getToolExecutableName riglet.tools;
    }
  ) evaluated.config.riglets;

  # XDG_CONFIG_HOME folder
  configRoot = pkgs.symlinkJoin {
    name = "${rigName}-config";
    paths = map (riglet: riglet.config-files) (attrValues evaluated.config.riglets);
  };

  # Docs folder (with symlinks to docs for all riglets)
  docRoot = pkgs.runCommand "${rigName}-docs" { } ''
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
  # Pre-sets most of flake.lib.genManifest args
  #
  # See lib/genManifest.nix for full documentation
  genManifest =
    args:
    flake.lib.genManifest (
      {
        inherit
          pkgs
          rigName
          rigMeta
          toolRoot
          docRoot
          configRoot
          ;
      }
      // args
    );

  entrypoint =
    if evaluated.config.entrypoint != null then evaluated.config.entrypoint baseRig else null;

  # Complete agent home directory
  home = pkgs.runCommand "${rigName}-home" { } ''
    mkdir -p $out
    ln -s ${toolRoot} $out/.local
    ln -s ${configRoot} $out/.config
    ln -s ${docRoot} $out/docs

    cat > $out/activate.sh <<EOF
    export PATH="$out/.local/bin:\$PATH"
    export XDG_CONFIG_HOME="$out/.config"
    EOF

    ln -s ${
      # The manifest will mention tools and docs by relative path for brevity
      genManifest {
        shownActivationScript = "./activate.sh";
        shownDocRoot = "./docs";
        shownToolRoot = "./.local";
        shownConfigRoot = "./.config";
      }
    } $out/RIG.md
  '';

  # Development shell with rig environment
  shell =
    let
      env = {
        XDG_CONFIG_HOME = configRoot;
        RIG_DOCS = docRoot;
        # The manifest will elude docs full paths via env var for brevity
        RIG_MANIFEST = genManifest {
          shownDocRoot = "$RIG_DOCS";
        };
      };
    in
    pkgs.mkShell {
      name = rigName;
      # Packages available in the shell. Sets PATH
      packages = [ toolRoot ];
      # Other environment variables
      inherit env;
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
          printf "  ${blue}Now in environment for rig \"${rigName}\".${reset}\n"
          printf "  ${yellow}\$RIG_MANIFEST${reset} contains the path of the ${green}RIG.md${reset} that your agent shoud\n"
          printf "  read first and foremost.\n"
          printf "  ${yellow}\$PATH${reset} exposes the rig tools.\n"
          echo ""
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
      newName ? rigName,
      extraModules ? [ ],
    }:
    flake.lib.buildRig {
      inherit pkgs;
      name = newName;
      modules = modules ++ extraModules;
    };

  # All command names of all tools through the rig
  commandNames = unique (flatten (map (rigletMeta: rigletMeta.commandNames) (attrValues rigMeta)));

  # Convert an option to a serializable format for inspection
  serializeOption =
    opt:
    let
      # Get type name, handling nested types
      getTypeName =
        t:
        let
          isEnum = t ? name && t.name == "enum";
        in
        # enums can be very long so we do not show their full type here
        if t ? description && !isEnum then
          t.description
        else if t ? name then
          t.name
        else
          "<unknown type>";

      # Extract enum values if this is an enum type
      enumValues =
        if opt ? type && opt.type ? functor && opt.type.functor ? payload then
          # For enum types, payload is { values = [...]; }
          if opt.type.functor.payload ? values then
            opt.type.functor.payload.values
          else
            opt.type.functor.payload
        else
          null;

      wrapValue =
        val:
        if pkgs.lib.isFunction val then
          # IMPORTANT: builtins.isFunction doesn't work here (it has false negatives)
          "<function>"
        else if (builtins.isAttrs val && val ? type && val.type == "derivation") || builtins.isPath val then
          "${val}"
        else
          val;
    in
    {
      description = opt.description or null;
      type = getTypeName (opt.type or { });
      default = if opt ? default then wrapValue opt.default else null;
      value = if opt.isDefined or false && opt ? value then wrapValue opt.value else null;
    }
    // pkgs.lib.optionalAttrs (enumValues != null && builtins.isList enumValues) {
      inherit enumValues;
    };

  # Recursively serialize the options tree, skipping certain internal options
  serializeOptionsTree =
    opts:
    let
      # Skip internal/system options that aren't user-facing
      shouldSkip =
        name:
        # Skip by name
        builtins.elem name [
          "_module"
          "entrypoint"
          "riglets"
        ];

      processAttr =
        name: opt:
        if shouldSkip name then
          null
        else if opt ? _type && opt._type == "option" then
          # This is a leaf option
          serializeOption opt
        else if opt ? options then
          # This has nested options (like a submodule), recurse into .options
          serializeOptionsTree opt.options
        else if builtins.isAttrs opt then
          # This is just an attribute group
          # Recurse directly into it
          serializeOptionsTree opt
        else
          null;

      processed = mapAttrs processAttr opts;
    in
    filterAttrs (_: v: v != null) processed;

  # Serialize the rig's config options for inspection
  configOptions = serializeOptionsTree evaluated.options;

  # Build the base rig attrset (without entrypoint and extend to avoid circularity)
  baseRig = {
    name = rigName;
    meta = rigMeta;
    inherit
      toolRoot
      configRoot
      docAttrs
      docRoot
      home
      shell
      genManifest
      commandNames
      configOptions
      ;
  };
in
baseRig
// {
  inherit extend;
}
// optionalAttrs (entrypoint != null) {
  inherit entrypoint;
}
