self:
{
  pkgs,
  riglib,
  ...
}:
let
  inherit (pkgs) lib;
in
{
  config.entrypoint =
    rig:
    let
      # Generate .vscode/mcp.json
      # IMPORTANT: VSCode uses "servers" as top-level key (NOT "mcpServers")
      mcpConfigJson = riglib.toJSON {
        servers = lib.mapAttrs (
          name: def:
          if def ? command then
            {
              type = "stdio";
              command = lib.getExe def.command;
            }
          else
            {
              type = if def.useSSE then "sse" else "http";
              inherit (def) url;
            }
            // lib.optionalAttrs (def.headers != { }) { inherit (def) headers; }
        ) rig.mcpServers;
      };

      # Generate terminal auto-approve rules from rig tools and deny rules
      autoApproveRules = riglib.toJSON (
        # Auto-approve all rig tools
        lib.genAttrs rig.allExeNames (_: true)
        # Deny specific subcommands via regex patterns
        // lib.mapAttrs' (
          tool: patterns: lib.nameValuePair "/^${tool}\\\\s+(${lib.concatStringsSep "|" patterns})/" false
        ) rig.denyRules
      );

      # Manifest will be copied to .github/copilot-instructions.md, and docs to .github/rig-docs/,
      # because Copilot's read_file tool is workspace-scoped and symlinks to /nix/store/ are resolved and then blocked
      manifestFile = pkgs.writeText "copilot-instructions.md" (
        builtins.readFile (
          rig.manifest.override {
            manifestFileName = "copilot-instructions.md";
            shownDocRoot = ".github/rig-docs";
            shownActivationScript = ".github/rig-activate.sh";
          }
        )
      );
    in
    pkgs.writeShellScriptBin "vscode-copilot-setup" ''
      set -euo pipefail

      info() {
        printf "> \033[0;36m%s\033[0m\n" "$1" >&2
      }

      warn() {
        printf "> \033[0;33m%s\033[0m\n" "$1" >&2
      }

      err() {
        printf "> \033[0;31m%s\033[0m\n" "$1" >&2
      }

      is-ignored () {
        ${lib.getExe pkgs.git} check-ignore "$1" > /dev/null
      }

      cp-if-ignored() {
        local flags="$1" src="$2" dest="$3"
        if is-ignored "$dest"; then
          [[ -d "$dest" ]] && rm -rf "$dest"
          cp $flags "$src" "$dest"
          chmod -R +w "$dest"
          info "Overwrote $dest"
        else
          err "$dest is not gitignored. Will not write it"
          exit 1
        fi
      }

      # Ensure directories exist
      if [ ! -d ".vscode" ]; then
        err ".vscode/ folder does not exist. Create it first"
        exit 1
      fi

      if [ ! -d ".github" ]; then
        err ".github/ folder does not exist. Create it first"
        exit 1
      fi

      # Copy rig manifest as Copilot instructions
      cp-if-ignored "" "${manifestFile}" ".github/copilot-instructions.md"

      # Copy docRoot into workspace so Copilot's read_file can access it
      #    (symlinks don't work: VSCode resolves them and blocks access outside workspace)
      cp-if-ignored "-rL" "${rig.docRoot}" ".github/rig-docs"

      # Copy MCP config
      cp-if-ignored "" "${mcpConfigJson}" ".vscode/mcp.json"

      # Copy activation script (provides PATH to rig tools)
      cp-if-ignored "" "${pkgs.writeText "rig-activate.sh" ''
        export PATH="${rig.toolRoot}/bin:$PATH"
      ''}" ".github/rig-activate.sh"

      # Merge terminal auto-approve rules into .vscode/settings.json
      if [ -f .vscode/settings.json ]; then
        ${lib.getExe pkgs.jq} -s \
          '.[0] * { "chat.tools.terminal.autoApprove": ((.[0]["chat.tools.terminal.autoApprove"] // {}) * .[1]) }' \
          .vscode/settings.json "${autoApproveRules}" > .vscode/settings.json.tmp
        mv .vscode/settings.json.tmp .vscode/settings.json
        info "Merged auto-approve rules into .vscode/settings.json"
      else
        ${lib.getExe pkgs.jq} -n \
          '{ "chat.tools.terminal.autoApprove": input }' \
          "${autoApproveRules}" > .vscode/settings.json
        info "Created .vscode/settings.json with auto-approve rules"
      fi

      # Generate prompt command files (only if there are any)
      ${lib.optionalString (rig.promptCommands != { }) ''
        mkdir -p .github/prompts
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (cmdName: cmd: ''
            ${lib.optionalString cmd.useSubAgent ''
              warn "prompt command '${cmdName}': useSubAgent not supported by VSCode (ignoring)"
            ''}
            cmdPath=".github/prompts/rig:${cmdName}.prompt.md"
            cp-if-ignored "" "${pkgs.writeText "rig:${cmdName}.prompt.md" ''
              ---
              description: ${cmd.description}
              ---

              ${cmd.template}
            ''}" "$cmdPath"
          '') rig.promptCommands
        )}
      ''}
    '';

  config.riglets.vscode-copilot = {
    meta = {
      description = "Set up project for use with VSCode + GitHub Copilot";
      intent = "base";
      disclosure = "none";
      status = "experimental";
      version = "0.1.0";
    };
  };
}
