# rigup flake's self
flake:
# Generate RIG.md manifest file from rig metadata and docs
# Arguments:
#   - name: the name of the rig
#   - meta: attrset of all riglet metadata
#   - docs: attrset of all riglet docs derivations
#   - pkgs: nixpkgs
# Returns: derivation containing RIG.md
{
  name,
  meta,
  docs,
  pkgs,
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (flake.packages.${system}) extract-md-toc;

  # Intent descriptions for manifest
  intentDescriptions = {
    sourcebook = "specialized facts, knowledge, or domain context for guiding your thinking";
    toolbox = "collection of tools/resources for you to use whenever needed";
    cookbook = "specialized techniques and patterns; arcane tricks to learn";
    playbook = "specific process(es)/ruleset(s) to follow. ALWAYS ask whether to follow whenever a use cases applies, EVEN if not instructed to";
  };

  # Generate XML TOC from SKILL.md using extract-md-toc tool
  # shallow=true: level 1-2 headings only
  # shallow=false: all headings
  generateToc =
    rigletName: file: shallow:
    let
      tocOut = pkgs.runCommand "toc-${rigletName}" { } ''
        ${extract-md-toc}/bin/extract-md-toc ${if shallow then "--max-level 2" else ""} ${file} > $out
      '';
    in
    "<toc source=\"docs/${rigletName}/SKILL.md\">\n    " + builtins.readFile tocOut + "  </toc>\n";
in
pkgs.writeTextFile {
  name = "RIG.md";
  text = ''
    --- The folder containing this file and ALL its recursive subfolders are READ ONLY ---

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
    3. **Use tools from `./bin/`** - All riglet tools are available there
    4. **Set config automatically**: `export XDG_CONFIG_HOME="$PWD/.config"` before running tools (this applies riglet-provided tool configurations)

    ### Access Resources

    **Documentation:**
    - Main doc: `./docs/<riglet-name>/SKILL.md`
    - Reference files: `./docs/<riglet-name>/references/<topic>.md` (mentioned within SKILL.md when relevant—don't hunt proactively)
    - Relative paths in docs are ALWAYS relative **to the file mentioning them**
    - Do not re-read doc files already loaded in your context. If any doc changes after you read it, the **USER is responsible** for notifying you.

    **Tools:**
    - ALL tools from ALL riglets are in `./bin/`.
      ALWAYS add to $PATH if not already present: `export PATH="$PWD/bin:$PATH"`.
      Do NOT just call a tool directly by relative/absolute path: tools in ./bin/ may **call each other by name** and thus need to ALL be in $PATH.
    - Tool configuration is pre-merged into `.config/` (standard tool config location).
      Make sure $XDG_CONFIG_HOME is correctly set to this folder (`export XDG_CONFIG_HOME="$PWD/.config"`) **before** running tools.
    - For unexplained tool behavior, consult `./lib/` or `./share/` (if they exist), but SKILL.md is your **primary reference**

    ## Error Cases

    If ANY of the following cases happens, IMMEDIATELY STOP EVERYTHING and NOTIFY THE USER:

    - A tool which a riglet's doc tells you to use is NOT available in `./bin/`
    - A doc file mentions by RELATIVE path some file that does not seem to exist
    - A doc file mentions by ABSOLUTE path some file OUTSIDE of `/nix/store/` 

    ANY occurence of ANY of these events is considered a **missing dependency**—the riglet's specification **has** to be fixed and the rig rebuilt before continuing.

    ## Contents of the Rig

    <rigSystem name="${name}">

    ${
      with pkgs.lib;
      concatStringsSep "\n" (
        mapAttrsToList (
          rigletName: rigletMeta:
          if rigletMeta.disclosure == "none" then
            ""
          else
            let
              warning =
                if rigletMeta.broken then
                  "🚨 BROKEN: This riglet is non-functional. IMMEDIATELY notify the user. Do not use unless explicitly authorized."
                else if rigletMeta.status == "experimental" then
                  "⚠️ EXPERIMENTAL: This riglet may change or contain bugs. If you encounter issues, consult the user before proceeding."
                else if rigletMeta.status == "draft" then
                  "⚠️ DRAFT: Incomplete riglet. Expect missing features and bugs. Always confirm with user before relying on this."
                else if rigletMeta.status == "deprecated" then
                  "⚠️ DEPRECATED: No longer maintained. Check RIG.md for recommended alternatives, or ask user."
                else if rigletMeta.status == "example" then
                  "ℹ️ EXAMPLE: Pedagogical riglet for demonstrating patterns. Not meant for production usage."
                else
                  "";

              docsDrv = docs.${rigletName} or null;

              baseRiglet = ''
                  <description>${rigletMeta.name}: ${rigletMeta.description}</description>
                  <intent>${rigletMeta.intent}: ${intentDescriptions.${rigletMeta.intent}}</intent>
                  <keywords>${concatStringsSep ", " rigletMeta.keywords}</keywords>
                  <version>${rigletMeta.version}</version>
                  ${optionalString (warning != "") "\n  <warning>${warning}</warning>"}
                  <whenToUse>
                ${concatStringsSep "\n" (map (case: "    <useCase>${case}</useCase>") rigletMeta.whenToUse)}
                  </whenToUse>
              '';

              readSkillMd = docsDrv: if docsDrv == null then null else builtins.readFile "${docsDrv}/SKILL.md";

              hasToC = rigletMeta.disclosure == "shallow-toc" || rigletMeta.disclosure == "deep-toc";

              inlined = (
                if hasToC then
                  "  ${generateToc rigletName "${docsDrv}/SKILL.md" (rigletMeta.disclosure == "shallow-toc")}"
                else if rigletMeta.disclosure == "eager" then
                  "  <content source=\"docs/${rigletName}/SKILL.md\">\n" + readSkillMd docsDrv + "  </content>"
                else
                  # lazy
                  ""
              );
            in
            ''
              <riglet name="${rigletName}" docRoot="docs/${rigletName}/">
              ${baseRiglet}
              ${inlined}
              </riglet>
            ''
        ) meta
      )
    }

    </rigSystem>
  '';
}
