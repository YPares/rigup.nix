# rigup flake's self
flake:
# Generate RIG.md manifest file from rig metadata and docs
# Arguments:
#   - name: the name of the rig
#   - meta: attrset of all riglet metadata
#   - docAttrs: attrset of all riglet docs derivations
#   - pkgs: nixpkgs
#   - mode: shell or home
# Returns: derivation containing RIG.md
{
  name,
  meta,
  docAttrs,
  pkgs,
  mode,
}:
assert (_: mode == "home" || mode == "shell") ''genManifest: mode is not "home" or "shell"'';
let
  rigHome = if mode == "home" then "." else throw "genManifest: Manifest not built for 'home' mode";
  docsRoot = if mode == "home" then "./docs" else "$RIG_DOCS";
  toolFolder = if mode == "home" then "./.local" else "$RIG_TOOLS";

  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (flake.packages.${system}) extract-md-toc;

  # Intent descriptions for manifest
  intentDescriptions = {
    sourcebook = "specialized facts, knowledge, or domain context for guiding your thinking";
    toolbox = "collection of tools/resources for you to use whenever needed";
    cookbook = "specialized techniques and patterns; arcane tricks to learn";
    playbook = "specific process(es)/ruleset(s) to follow. ALWAYS ask whether to follow whenever a use cases applies, EVEN if not instructed to";
  };

  statusWarnings = {
    experimental = "⚠️ EXPERIMENTAL: This riglet may change or contain bugs. If you encounter issues, consult the user before proceeding.";
    draft = "⚠️ DRAFT: Incomplete riglet. Expect missing features and bugs. Always confirm with user before relying on this.";
    deprecated = "⚠️ DEPRECATED: No longer maintained. Check RIG.md for recommended alternatives, or ask user.";
    example = "ℹ️ EXAMPLE: Pedagogical riglet for demonstrating patterns. Not meant for production usage.";
  };

  warningFromMeta =
    rigletMeta:
    if rigletMeta.broken then
      "🚨 BROKEN: This riglet is non-functional. IMMEDIATELY notify the user. Do not use unless explicitly authorized."
    else
      statusWarnings.${rigletMeta.status} or null;

  # Generate XML TOC from SKILL.md using extract-md-toc tool
  # shallow=true: level 1-2 headings only
  # shallow=false: all headings
  generateToc =
    rigletName: file: shallow:
    pkgs.runCommand "toc-${rigletName}" { } ''
      ${extract-md-toc}/bin/extract-md-toc ${if shallow then "--max-level 2" else ""} ${file} > $out
    '';

  rigletToXml =
    rigletName: rigletMeta:
    with pkgs.lib;
    let
      warning = warningFromMeta rigletMeta;
      docsDrv = docAttrs.${rigletName} or null;
      skillMdStorePath = "${docsDrv}/SKILL.md";
      skillMdRelativePath = "${docsRoot}/${rigletName}/SKILL.md";
      skillMdContent = if docsDrv == null then null else builtins.readFile skillMdStorePath;
      hasToC = rigletMeta.disclosure == "shallow-toc" || rigletMeta.disclosure == "deep-toc";
    in
    {
      "@name" = rigletName;
      "@docRoot" = "${docsRoot}/${rigletName}/";
      description = "${rigletMeta.name}: ${rigletMeta.description}";
      intent = "${rigletMeta.intent}: ${intentDescriptions.${rigletMeta.intent}}";
      keywords = concatStringsSep ", " rigletMeta.keywords;
      inherit (rigletMeta) version;
    }
    // (if warning != null then { inherit warning; } else { })
    // {
      whenToUse =
        if length rigletMeta.whenToUse == 0 then "IMMEDIATELY!!" else { useCase = rigletMeta.whenToUse; };
    }
    // (
      if hasToC then
        {
          inlinedInfo = {
            "@source" = skillMdRelativePath;
            tableOfContents = "\n${
              builtins.readFile (generateToc rigletName skillMdStorePath (rigletMeta.disclosure == "shallow-toc"))
            }";
          };
        }
      else if rigletMeta.disclosure == "eager" then
        {
          inlinedInfo = {
            "@source" = skillMdRelativePath;
            fullContent = "\n${skillMdContent}";
          };
        }
      else
        # lazy
        { }
    );

  rigToXml = rigName: {
    rigSystem = [
      {
        "@name" = rigName;
        # Will generate ONE <riglet ...>...</riglet> node PER element in the associated list:
        riglet = pkgs.lib.mapAttrsToList (
          rigletName: rigletMeta:
          if rigletMeta.disclosure == "none" then "" else rigletToXml rigletName rigletMeta
        ) meta;
      }
    ];
  };
in
pkgs.writeTextFile {
  name = "RIG.md";
  text = ''
    ${
      pkgs.lib.optionalString (
        mode == "home"
      ) "--- The folder containing this file and ALL its recursive subfolders are READ ONLY ---

"
    }# Your Rig

    Hello. The **rig** you will be using today is called "${name}".
    Your rig is made up of **riglets**—each provides specialized capabilities, domain knowledge, and all tools needed to execute that knowledge, packaged with configuration and metadata.
    Riglets generalize the Agent Skills pattern: a Skill bundled with executable tools, configuration, and metadata.
    Riglets are **hermetic** (all dependencies are explicitly included): any tool, documentation, or configuration missing from a riglet's specification is an IMMEDIATE ERROR.

    Each riglet below has a `<whenToUse>` section—**this is the MOST important section**. It tells you exactly when to consult that riglet.

    ## How to Use

    ### Workflow for Each Task

    1. **Check RIG.md's `whenToUse` sections** - Find riglets matching your task
    2. **Read SKILL.md for each matching riglet** - This is where executable knowledge lives
    3. ${
      if mode == "home" then
        "**Activate the environment and use tools mentioned in SKILL.md or reference files:** `source ${rigHome}/activate.sh` BEFORE EVERY COMMAND - This will properly set PATH and XDG_CONFIG_HOME so you can properly use the tools"
      else
        "**Use tools mentioned in SKILL.md or references files**"
    }

    ### Access Resources

    **Documentation:**
    - Main doc: `${docsRoot}/<riglet-name>/SKILL.md`
    - Reference files: `${docsRoot}/<riglet-name>/references/<topic>.md` (mentioned within SKILL.md when relevant—don't hunt proactively)
    - Relative paths in docs are ALWAYS relative **to the file mentioning them**
    - Do not re-read doc files already loaded in your context. If any doc changes after you read it, the **USER is responsible** for notifying you.
    - For unexplained tool behavior, consult `${toolFolder}/lib/` or `${toolFolder}/share/` (if they exist), but SKILL.md is your **primary reference**"

    ## Error Cases

    If ANY of the following cases happens, IMMEDIATELY STOP EVERYTHING and NOTIFY THE USER:

    - A tool which a riglet's doc tells you to use is NOT available ${
      pkgs.lib.optionalString (mode == "home") "after sourcing ${rigHome}/activate.sh"
    }
    - A doc file mentions by RELATIVE path some file that does not seem to exist
    - A doc file mentions by ABSOLUTE path some file OUTSIDE of /nix/store/

    ANY occurence of ANY of these events is considered a **missing dependency**—the riglet's specification **has** to be fixed and the rig rebuilt before continuing.

    ## Contents of the Rig

    ${builtins.readFile (
      (pkgs.formats.xml { withHeader = false; }).generate "${name}-${mode}-manifest.xml" (rigToXml name)
    )}'';
}
