# rigup flake's self
flake:
# Generate RIG.md manifest file from rig metadata and docs
# Arguments:
#   - pkgs: nixpkgs
#   - mode: shell or home
#   - name: the name of the rig
#   - meta: attrset of all riglet metadata
#   - docRoot: absolute Nix store path to the folder containing all docs of the rig
#   - shownDocRoot: path or env var to use as the folder containing all docs, to use in the manifest. Defaults to docRoot
#   - shownToolRoot: (Optional) path or env var to use as the folder containing bin/, lib/, share/ etc. for all tools of the rig, to indicate the agent they can if needed look for additional info under share/ and lib/
#   - shownActivationScript: (Optional) path or env var to use as a script path that should be sourced before every command (to set env vars)
# Returns: derivation containing RIG.md
{
  pkgs,
  name,
  meta,
  docRoot,
  shownDocRoot ? docRoot,
  shownToolRoot ? null,
  shownActivationScript ? null,
}:
with builtins;
with pkgs.lib;
let
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (flake.packages.${system}) extract-md-toc;

  # Intent descriptions for manifest
  intentDescriptions = {
    base = throw "Riglets with intent \"base\" should not be disclosed in the manifest: set meta.disclosure = \"none\"";
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
    pkgs.runCommand "${rigletName}-${optionalString shallow "shallow-"}toc" { } ''
      ${extract-md-toc}/bin/extract-md-toc ${if shallow then "--max-level 2" else ""} ${file} > $out
    '';

  rigletToXml =
    rigletName: rigletMeta:
    {
      "@name" = rigletName;
      "@docRoot" = "${shownDocRoot}/${rigletName}/";
      inherit (rigletMeta) description;
      intent = "${rigletMeta.intent}: ${intentDescriptions.${rigletMeta.intent}}";
      keywords = concatStringsSep ", " rigletMeta.keywords;
      inherit (rigletMeta) version;
    }
    // (
      let
        warning = warningFromMeta rigletMeta;
      in
      optionalAttrs (warning != null) { inherit warning; }
    )
    // optionalAttrs (rigletMeta.whenToUse != [ ]) {
      whenToUse.useCase = rigletMeta.whenToUse;
    }
    // (
      let
        skillMdPath = "${docRoot}/${rigletName}/SKILL.md";
        shownSkillMdPath = "${shownDocRoot}/${rigletName}/SKILL.md";
      in
      if
        elem rigletMeta.disclosure [
          "shallow-toc"
          "deep-toc"
        ]
      then
        {
          inlinedInfo = {
            "@source" = shownSkillMdPath;
            tableOfContents = "\n${
              readFile (generateToc rigletName skillMdPath (rigletMeta.disclosure == "shallow-toc"))
            }";
          };
        }
      else if rigletMeta.disclosure == "eager" then
        {
          inlinedInfo = {
            "@source" = shownSkillMdPath;
            fullContent = "\n${readFile skillMdPath}";
          };
        }
      else
        # lazy
        { }
    );

  rigToXml = rigName: {
    rigSystem = {
      "@name" = rigName;
      # Will generate ONE <riglet ...>...</riglet> node PER element in the associated list:
      riglet = filter (x: x != null) (
        mapAttrsToList (
          rigletName: rigletMeta:
          if rigletMeta.disclosure == "none" then null else rigletToXml rigletName rigletMeta
        ) meta
      );
    };
  };
in
pkgs.writeTextFile {
  name = "RIG.md";
  text = ''
    # Your Rig

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
      if shownActivationScript != null then
        "**Activate the environment and use tools mentioned in SKILL.md or reference files:** `source ${shownActivationScript}` BEFORE EVERY COMMAND - This will properly set PATH and XDG_CONFIG_HOME so you can properly use the tools"
      else
        "**Use tools mentioned in SKILL.md or references files**"
    }

    ### Access Resources

    **Documentation:**
    - Main doc: `${shownDocRoot}/<riglet-name>/SKILL.md`
    - Reference files: `${shownDocRoot}/<riglet-name>/references/<topic>.md` (mentioned within SKILL.md when relevant—don't hunt proactively)
    - Relative paths in docs are ALWAYS relative **to the file mentioning them**
    - Do not re-read doc files already loaded in your context. If any doc changes after you read it, the **USER is responsible** for notifying you.
    ${optionalString (shownToolRoot != null) ''
      - For unexplained tool behavior, consult `${shownToolRoot}/share/` or `${shownToolRoot}/lib/` (if they exist), but SKILL.md is your **primary reference**
    ''}
    ## Error Cases

    If ANY of the following cases happens, IMMEDIATELY STOP EVERYTHING and NOTIFY THE USER:

    - A tool which a riglet's doc tells you to use is NOT available ${
      optionalString (shownActivationScript != null) "after sourcing ${shownActivationScript}"
    }
    - A doc file mentions by RELATIVE path some file that does not seem to exist
    - A doc file mentions by ABSOLUTE path some file OUTSIDE of /nix/store/

    ANY occurence of ANY of these events is considered a **missing dependency**—the riglet's specification **has** to be fixed and the rig rebuilt before continuing.

    ## Contents of the Rig

    ${readFile (
      (pkgs.formats.xml { withHeader = false; }).generate "${name}-manifest.xml" (rigToXml name)
    )}'';
}
