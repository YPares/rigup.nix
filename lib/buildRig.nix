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
  # Pre-sets the flake.lib.genManifest args
  # Optional extra args left unset: shownDocRoot, shownToolRoot, shownActivationScript
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

  entrypoint =
    if evaluated.config.entrypoint != null then evaluated.config.entrypoint baseRig else null;

  # Complete agent home directory
  home = pkgs.runCommand "${name}-home" { } ''
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

    ${optionalString (entrypoint != null) ''
      ln -s "${entrypoint}" $out/entrypoint
    ''}
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
      }
      // optionalAttrs (entrypoint != null) {
        RIG_ENTRYPOINT = pkgs.lib.getExe entrypoint;
      };
    in
    pkgs.mkShell {
      inherit name;
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
          printf "  ${blue}Now in environment for rig \"${name}\".${reset}\n"
          printf "  ${yellow}\$RIG_MANIFEST${reset} contains the path of the ${green}RIG.md${reset} that your agent shoud\n"
          printf "  read first and foremost.\n"
          printf "  ${yellow}\$PATH${reset} exposes the rig tools.\n"
          ${optionalString (entrypoint != null) ''
            printf "  ${yellow}\$RIG_ENTRYPOINT${reset} exposes the rig entrypoint (${green}${entrypoint.name}${reset}).\n"
          ''}
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
      newName ? name,
      extraModules ? [ ],
    }:
    flake.lib.buildRig {
      inherit pkgs;
      name = newName;
      modules = modules ++ extraModules;
    };

  # All command names of all tools through the rig
  commandNames = unique (flatten (map (rigletMeta: rigletMeta.commandNames) (attrValues meta)));

  # Check if a value can be safely serialized
  # Returns true if the value is not a function, derivation, or path
  canSerialize =
    val:
    !(
      builtins.isFunction val
      || (builtins.isAttrs val && val ? type && val.type == "derivation")
      || builtins.isPath val
    );

  # Convert an option to a serializable format for inspection
  serializeOption =
    opt:
    let
      # Get type name, handling nested types
      getTypeName =
        t:
        if t ? name then
          t.name
        else if t ? description then
          t.description
        else
          "unknown";

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
    in
    {
      description = opt.description or null;
      type = getTypeName (opt.type or { });
      isDefined = opt.isDefined or false;
      # Only include default if it exists and can be serialized
      default = if opt ? default && canSerialize opt.default then opt.default else null;
      # Similarly for value
      value = if opt.isDefined or false && opt ? value && canSerialize opt.value then opt.value else null;
      # Include enum values if available
      enumValues = if enumValues != null && builtins.isList enumValues then enumValues else null;
    };

  # Check if a type involves functions (recursively)
  typeInvolvesFunctions =
    t:
    if !builtins.isAttrs t then
      false
    else if t ? name && t.name == "functionTo" then
      true
    else if t ? nestedTypes && builtins.isList t.nestedTypes then
      # For types like nullOr, oneOf, etc. that have nested types as a list
      builtins.any typeInvolvesFunctions t.nestedTypes
    else if t ? elemType then
      # For types that have a single nested type (like listOf, attrsOf, etc.)
      typeInvolvesFunctions t.elemType
    else
      false;

  # Recursively serialize the options tree, skipping certain internal options
  serializeOptionsTree =
    opts:
    let
      # Skip internal/system options that aren't user-facing
      # Also skip known function-typed options and options with non-serializable types
      shouldSkip =
        name: opt:
        # Skip by name
        builtins.elem name [
          "_module"
          "entrypoint" # Always a function
          "riglets" # Internal riglet definitions (already shown in Riglets section)
        ]
        # Skip by type
        || (
          opt ? _type
          && opt._type == "option"
          && opt ? type
          && (
            typeInvolvesFunctions opt.type
            || (
              opt.type ? name
              && builtins.elem opt.type.name [
                "package"
                "path"
              ]
            )
          )
        );

      processAttr =
        name: opt:
        if shouldSkip name opt then
          null
        else if opt ? _type && opt._type == "option" then
          # This is a leaf option
          serializeOption opt
        else if opt ? options then
          # This has nested options (like a submodule), recurse into .options
          serializeOptionsTree opt.options
        else if builtins.isAttrs opt then
          # This is just an attribute group (like "agent" containing "identity")
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
