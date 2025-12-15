# Generate RIG.md manifest from rig metadata
{ pkgs }:
with pkgs.lib;
{
  # Generate RIG.md manifest file from rig metadata
  # Arguments:
  #   - name: the name of the rig
  #   - meta: attrset of all riglet metadata
  # Returns: derivation containing RIG.md
  generateManifest =
    { name, meta }:
    pkgs.writeTextFile {
      name = "RIG.md";
      text = ''
        # Your Rig

        Hello. The rig you will be using today is called _${name}_.
        Your rig provides technical and operational documentation and the tools needed to execute it.

        A _riglet_ (similar to an Agent Skill) contains instructions about related operations, methods, commands etc. that are handy when working on a project.
        Contrary to a Skill, a riglet will come packaged with every tool needed to execute on the knowledge it contains, plus useful extra metadata.

        Each riglet will notably mention a <whenToUse> section that will tell you WHEN to consult it, like "if working on source files of type XXX", "when trying to debug a case of YYY", "when in need of documentation about ZZZ"...
        This is the most important section of each riglet below.

        ## How to Use

        **Access documentation:**
        - Location: `./docs/<riglet-name>/SKILL.md`
        - Read main docs: `cat ./docs/<riglet-name>/SKILL.md`
        - Read references: `cat ./docs/<riglet-name>/references/<topic>.md`

        **Use the rig's tools:**
        - All tools are available in `./bin/`
        - Call them directly via absolute path, or add folder to PATH: `export PATH="$PWD/bin:$PATH"`

        ## Available Riglets

        <rig_system>

        ${concatStringsSep "\n" (
          mapAttrsToList (
            rigletName: rigletMeta:
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
            in
            ''
              <riglet>
                <name>${rigletName}</name>
                <title>${rigletMeta.name}</title>
                <description>${rigletMeta.description}</description>
                <keywords>${concatStringsSep ", " rigletMeta.keywords}</keywords>
                <version>${rigletMeta.version}</version>${
                  optionalString (warning != "") "\n  <warning>${warning}</warning>"
                }
                <whenToUse>
              ${concatStringsSep "\n" (map (use: "    - ${use}") rigletMeta.whenToUse)}
                </whenToUse>
                <docs>docs/${rigletName}/</docs>
              </riglet>
            ''
          ) meta
        )}

        </rig_system>
      '';
    };
}
