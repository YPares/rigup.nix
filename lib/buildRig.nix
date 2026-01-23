# rigup flake's self
flake:
# Evaluate a rig from a set of riglet modules
# Returns an attrset with:
#   - name: the rig name
#   - toolRoot: tools' bin/, lib/, share/, etc. folders combined via symlinks
#   - configRoot: configFiles for _wrapped_ tools combined via symlinks
#   - docAttrs: attrset of riglet name -> doc folder derivation
#   - docRoot: riglet docs, one subfolder per riglet, combined via symlinks
#   - meta: attrset of riglet name -> metadata
#   - configOptions: serializable nested attrset of option name -> option info (description, type, default, value)
#   - home: complete rig directory (RIG.md + bin/ + docs/ + .config/)
#   - shell: complete rig, in devShell form (slightly different manifest to directly read from nix store instead of local symlinks)
#   - modules: the set of modules passed to buildRig
#   - extend: function that takes a list of extra riglet modules and combines them with those of the rig
#   - entrypoint: null, or folder derivation with `bin/<entrypoint_executable>`
#   - manifest: default manifest with full Nix store paths, overridable to show shorter paths (see flake.lib.genManifest for available args)
#   - allExeNames: the list of all executable commands exposed by the rig
#   - mcpServers: attrset of MCP server name -> { rigletName, transport, url, resolvedCommand }
#   - configOptions: nested attrset of options exposed by the rig, in serializable form, for discovery purposes
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

  # Extract the executable or package name from a tool (using eval-time metadata).
  # This is only for indicative purposes, as for some packages this name might not match an actual
  # exe name once the package is built, and some packages may expose several exes.
  # However, this already permits to extract some useful metadata from riglets (that the rigup CLI
  # can show) **prior** to building the tool derivations (and therefore we avoid IFD)
  getToolMainProgramName =
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

  # Docs per riglet
  docAttrs = mapAttrs (_: riglet: riglet.docs) evaluated.config.riglets;

  # Metadata per riglet, enriched with mainProgram name for each provided tool
  rigMeta = mapAttrs (
    rigletName: riglet:
    riglet.meta
    // {
      # Add computed command names to each riglet's metadata
      commandNames =
        let
          normalized = normalizeTools riglet.tools;
        in
        map getToolMainProgramName (normalized.wrapped ++ normalized.unwrapped);
    }
  ) evaluated.config.riglets;

  # XDG_CONFIG_HOME folder to set for all _wrapped_ tools
  configRoot = pkgs.symlinkJoin {
    name = "rig-config-root";
    paths = map (riglet: riglet.configFiles) (attrValues evaluated.config.riglets);
  };

  normalizeTools =
    tools:
    let
      # Normalize a tool item: if it's a path, wrap it with wrapScriptPath; otherwise return as-is
      normalizeOne = tool: if builtins.isPath tool then riglib.wrapScriptPath tool else tool;
    in
    if builtins.isList tools then
      {
        wrapped = map normalizeOne tools;
        unwrapped = [ ];
      }
    else
      {
        wrapped = map normalizeOne tools.wrapped;
        unwrapped = map normalizeOne tools.unwrapped;
      };

  accumRigletTools =
    acc: riglet:
    let
      normalized = normalizeTools riglet.tools;
    in
    {
      wrapped = acc.wrapped ++ normalized.wrapped;
      unwrapped = acc.unwrapped ++ normalized.unwrapped;
    };

  wrapWithConfigHome =
    tools:
    riglib.wrapWithEnv {
      name = "rig-wrapped-tools";
      inherit tools;
      env.XDG_CONFIG_HOME = configRoot;
    };

  # Combined tools from all riglets
  toolRoot =
    let
      allTools = foldl' accumRigletTools {
        wrapped = [ ];
        unwrapped = [ ];
      } (attrValues evaluated.config.riglets);
    in
    pkgs.buildEnv {
      name = "rig-all-tools";
      paths = [ (wrapWithConfigHome allTools.wrapped) ] ++ allTools.unwrapped;
    };

  # Docs folder (with symlinks to docs for all riglets)
  docRoot = pkgs.runCommandLocal "rig-doc-root" { } ''
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

  # The rig manifest file from riglet metadata and docs, overridable
  #
  # See lib/genManifest.nix for full documentation
  manifest = makeOverridable flake.lib.genManifest {
    inherit
      pkgs
      rigName
      rigMeta
      toolRoot
      docRoot
      configRoot
      ;
  };

  entrypoint =
    if evaluated.config.entrypoint != null then evaluated.config.entrypoint baseRig else null;

  # Complete agent home directory
  home = pkgs.runCommandLocal "rig-home" { } ''
    mkdir -p $out
    ln -s ${toolRoot} $out/.local
    ln -s ${configRoot} $out/.config
    ln -s ${docRoot} $out/docs

    cat > $out/activate.sh <<EOF
    export PATH="$out/.local/bin:\$PATH"
    EOF

    ln -s ${
      # The manifest will mention tools and docs by relative path for brevity
      manifest.override {
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
        RIG_DOCS = docRoot;
        # The manifest will elude docs full paths via env var for brevity
        RIG_MANIFEST = manifest.override {
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

  allExesDeriv = pkgs.runCommandLocal "rig-all-exes" { } ''
    dir="${toolRoot}/bin"
    if [ -d "$dir" ]; then
      ls ${toolRoot}/bin > $out
    else
      echo "" > $out
    fi
  '';

  # All commands available through the rig
  allExeNames = builtins.filter (s: s != "") (splitString "\n" (builtins.readFile allExesDeriv));

  # Collect promptCommands from all riglets
  promptCommands =
    let
      collectFromRiglet =
        rigletName: riglet:
        concatMapAttrs (commandName: def: {
          "${rigletName}:${commandName}" =
            def
            // optionalAttrs (def.readDocsFirst && riglet.docs != null && riglet.meta.disclosure != "eager") {
              template = ''
                **First, if not done already, read mainDocFile of riglet ${rigletName}.**

                ${def.template}
              '';
            };
        }) riglet.promptCommands;
    in
    foldl' (acc: r: acc // collectFromRiglet r.name r) { } (
      mapAttrsToList (n: r: r // { name = n; }) evaluated.config.riglets
    );

  # Collect MCP servers from all riglets
  mcpServers =
    let
      collectFromRiglet =
        rigletName: riglet:
        mapAttrs (
          serverName: def:
          def
          // {
            inherit rigletName;
            # Handle nullable command (remote servers have no local command)
            resolvedCommand = if def.command != null then getExe def.command else null;
          }
        ) riglet.mcpServers;
    in
    foldl' (acc: r: acc // collectFromRiglet r.name r) { } (
      mapAttrsToList (n: r: r // { name = n; }) evaluated.config.riglets
    );

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
        if isFunction val then
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
    // optionalAttrs (enumValues != null && builtins.isList enumValues) {
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

  # The base rig attrset (without 'entrypoint' and 'extend' to avoid circularity)
  # that will be fed to the 'entrypoint' function if one riglet defines it
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
      manifest
      allExeNames
      modules
      promptCommands
      mcpServers
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
