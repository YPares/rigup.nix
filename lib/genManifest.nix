# rigup flake's self
flake:
# Generate rig manifest file from rig metadata and docs
# Arguments:
#   - pkgs: nixpkgs
#   - mode: shell or home
#   - rigName: name of the rig
#   - rigMeta: attrset of all riglet metadata
#   - docRoot: absolute Nix store path to the folder containing all docs of the rig
#   - shownDocRoot: path or env var to use as the folder containing all docs, to use in the manifest. Defaults to docRoot
#   - shownToolRoot: (Optional) path or env var to use as the folder containing bin/, lib/, share/ etc. for all tools of the rig, to indicate the agent they can if needed look for additional info under share/ and lib/
#   - shownActivationScript: (Optional) path or env var to use as a script path that should be sourced before every command (to set env vars)
#   - missingDepsIsCriticalError: Bool (true by default). Whether to tell the agent to consider any missing dependency (tool or filepath mentioned) as a critical error
#   - manifestName: (Optional) How should the manifest file refer to itself ("RIG.md" by default)
# Returns: file derivation
{
  pkgs,
  rigName,
  rigMeta,
  toolRoot,
  docRoot,
  configRoot,
  shownToolRoot ? toolRoot,
  shownDocRoot ? docRoot,
  shownConfigRoot ? configRoot,
  shownActivationScript ? null,
  missingDepsIsCriticalError ? true,
  manifestFileName ? "RIG.md",
}:
with builtins;
with pkgs.lib;
let
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (flake.packages.${system}) extract-md-toc;
  riglib = flake.lib.mkRiglib { inherit pkgs; };

  # Intent descriptions for manifest
  intentDescriptions = rigletName: {
    base = throw ''
      Riglet ${rigletName} has intent "base" and should not be disclosed in the manifest: set meta.disclosure = "none"
    '';
    sourcebook = "specialized facts, knowledge, or domain context for guiding your thinking";
    toolbox = "collection of tools/resources for you to use whenever needed";
    cookbook = "specialized techniques and patterns; arcane tricks to learn";
    playbook = "specific process(es)/ruleset(s) to follow. ALWAYS ask whether to follow whenever a use cases applies, EVEN if not instructed to";
  };

  statusWarnings = {
    experimental = "⚠️ EXPERIMENTAL: This riglet may change or contain bugs. If you encounter issues, consult the user before proceeding.";
    draft = "⚠️ DRAFT: Incomplete riglet. Expect missing features and bugs. Always confirm with user before relying on this.";
    deprecated = "⚠️ DEPRECATED: No longer maintained. Check ${manifestFileName} for recommended alternatives, or ask user.";
    example = "ℹ️ EXAMPLE: Pedagogical riglet for demonstrating patterns. Not meant for production usage.";
  };

  warningFromMeta =
    rigletMeta:
    if rigletMeta.broken then
      "🚨 BROKEN: This riglet is non-functional. IMMEDIATELY notify the user. Do not use unless explicitly authorized."
    else
      statusWarnings.${rigletMeta.status} or null;

  # Generate table of contents from riglet's meta.mainDocFile using extract-md-toc
  # shallow=true: level 1-2 headings only
  # shallow=false: all headings
  generateToc =
    rigletName: file: shallow:
    pkgs.runCommandLocal "${rigletName}-${optionalString shallow "shallow-"}toc" { } ''
      ${extract-md-toc}/bin/extract-md-toc ${if shallow then "--max-level 2" else ""} ${file} > $out
    '';

  rigletToXml =
    rigletName: rigletMeta:
    let
      mainDocFile = "${docRoot}/${rigletName}/${rigletMeta.mainDocFile}";
      shownMainDocFile = "${shownDocRoot}/${rigletName}/${rigletMeta.mainDocFile}";
      optionalMeta =
        if rigletMeta.disclosure == "eager" then
          { }
        else
          {
            inherit (rigletMeta) description;
            keywords = concatStringsSep ", " rigletMeta.keywords;
          }
          // optionalAttrs (rigletMeta.whenToUse != [ ]) {
            whenToUse.useCase = rigletMeta.whenToUse;
          };
      mainDocFileInfo =
        if rigletMeta.disclosure == "eager" then
          { fullContent = "\n${readFile mainDocFile}"; }
        else if
          elem rigletMeta.disclosure [
            "shallow-toc"
            "deep-toc"
          ]
        then
          {
            tableOfContents = "\n${
              readFile (generateToc rigletName mainDocFile (rigletMeta.disclosure == "shallow-toc"))
            }";
          }
        else
          # lazy
          { };
    in
    if !builtins.pathExists mainDocFile then
      throw ''
        genManifest: ${rigletName}.meta.mainDocFile ("${rigletMeta.mainDocFile}") not found in riglet's docs
      ''
    else
      {
        "@name" = rigletName;
        "@version" = rigletMeta.version;
        "@intent" = rigletMeta.intent;
        whatItContains = (intentDescriptions rigletName).${rigletMeta.intent};
        mainDocFile = {
          "@source" = shownMainDocFile;
        }
        // mainDocFileInfo;
      }
      // optionalMeta
      // (
        let
          warning = warningFromMeta rigletMeta;
        in
        optionalAttrs (warning != null) { inherit warning; }
      );

  rigToXML = rigName: {
    rigSystem = {
      "@name" = rigName;
      # Will generate ONE <riglet> tag PER element in the associated list:
      riglet = filter (x: x != null) (
        mapAttrsToList (
          rigletName: rigletMeta:
          if rigletMeta.disclosure == "none" then null else rigletToXml rigletName rigletMeta
        ) rigMeta
      );
    };
  };
in
pkgs.writeTextFile {
  name = manifestFileName;
  text = ''
    # `${manifestFileName}`

    Hello. The **rig** you will be using today is called "${rigName}".
    Your rig is made up of **riglets**—each provides specialized capabilities, domain knowledge, and all tools needed to execute that knowledge, packaged with configuration and metadata.
    Riglets generalize the Agent Skills pattern: a Skill bundled with executable tools, configuration, and metadata.
    Riglets below have `whatItContains` and `whenToUse` sections—**these are the MOST important sections**. They tell you exactly what to expect from the riglet's doc and when to consult it.
    **When in doubt whether to use a riglet or not: USE IT.**

    ## How to Use

    ### Workflow for Each Task

    1. **Check ${manifestFileName}'s `whenToUse` sections** - Find riglets matching your task
    2. **Read the `mainDocFile` for each matching riglet** - This is where executable knowledge lives
    3. ${
      if shownActivationScript != null then
        "**Activate the environment and use tools mentioned in riglet doc files:** `source ${shownActivationScript}` BEFORE EVERY COMMAND - This will set PATH so you can use the tools"
      else
        "**Use tools mentioned in riglet doc files**"
    }

    ### Access Resources

    **Documentation:**
    ${optionalString (shownDocRoot != docRoot) ''
      - The folder containing all rig docs is `${docRoot}`, abbreviated here as `${shownDocRoot}`
    ''}
    - Each riglet listed below will mention its `mainDocFile`: it is the one you should always read **first**
    - If there is more to read, the rest of a riglet's doc files will always be mentioned **explicitly** in its `mainDocFile`. DO NOT hunt for them proactively
    - Relative paths in docs are ALWAYS relative **to the file mentioning them**
    - Do not re-read doc files already loaded in your context. If any doc changes after you read it, the **USER is responsible** for notifying you

    ${optionalString (shownToolRoot != null) ''
      **Tools:**
      For unexplained tool behavior or troubleshooting purposes, you may consult `${shownToolRoot}/` subfolders such as `share/` and `lib/` if they exist, but the riglets' docs are your **primary reference**.
    ''}
    ${optionalString (shownConfigRoot != null) ''
      **Configuration:**
      Config files for tools following the XDG Base Directory Specification are in `${shownConfigRoot}/`. You should NOT have to care about them: the tools which need this are **already wrapped** to use this config folder. This is ONLY mentioned for troubleshooting purposes.
    ''}
    ${optionalString missingDepsIsCriticalError ''
      ## Error Cases

      If ANY of the following cases happens, IMMEDIATELY STOP EVERYTHING and NOTIFY THE USER:

      - A tool which a riglet's doc tells you to use is NOT available ${
        optionalString (shownActivationScript != null) "after sourcing ${shownActivationScript}"
      }
      - A doc file mentions by RELATIVE path some file that does not seem to exist
      - A doc file mentions by ABSOLUTE path some file OUTSIDE of /nix/store/

      ANY occurence of ANY of these events is considered a **missing dependency**—the riglet's specification **has** to be fixed and the rig rebuilt before continuing.
    ''}
    ## Contents of the Rig

    ${readFile (riglib.toXML (rigToXML rigName))}'';
}
