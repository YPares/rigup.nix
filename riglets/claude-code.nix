self:
{
  pkgs,
  system,
  lib,
  config,
  riglib,
  ...
}:
let
  inherit (self.inputs.llm-agents.packages.${system}) claude-code;
in
{
  imports = [ self.riglets.models ];

  options.claude-code = with lib; {
    strictMcpConfig = mkOption {
      description = "Deactivate all MCP servers besides those configured in the rig";
      type = types.bool;
      default = false;
    };
  };

  # Define the entrypoint for this rig - launches Claude Code with rig context
  config.entrypoint =
    rig:
    let
      manifestPath = rig.manifest.override { shownDocRoot = "$RIG_DOCS"; };

      settingsJson = riglib.toJSON (
        {
          # Grant read access to specific Nix store paths that Claude Code needs
          permissions.allow = [
            "Read(${manifestPath})" # The RIG.md manifest file
            "Read(${rig.docRoot}/**)" # All documentation files
            "Read(${rig.configRoot}/**)" # All config files
            "Read(${rig.toolRoot}/**)" # Tool files (for inspecting share/, lib/, etc.)
          ]
          ++ map (cmd: "Bash(${cmd}:*)") rig.allExeNames; # Allow executing all rig tools

          # Add deny rules for specific tool subcommands
          # Format: Bash(tool subcommand:*) - the colon is BEFORE the asterisk, after the full command
          permissions.deny = lib.flatten (
            lib.mapAttrsToList (
              tool: patterns: map (pattern: "Bash(${tool} ${pattern}:*)") patterns
            ) rig.denyRules
          );
        }
        // lib.optionalAttrs (config.models.default.modelId != null) {
          model = config.models.default.modelId;
        }
      );

      mcpConfig = riglib.toJSON {
        mcpServers = pkgs.lib.mapAttrs (
          name: s:
          {
            type = s.transport;
          }
          // pkgs.lib.optionalAttrs (s.resolvedCommand != null) { command = s.resolvedCommand; }
          // pkgs.lib.optionalAttrs (s.url != null) { inherit (s) url; }
          // pkgs.lib.optionalAttrs (s.headers != { }) { inherit (s) headers; }
        ) rig.mcpServers;
      };

      # Generate Claude Code plugin for prompt commands (only if there are any)
      pluginDir =
        if rig.promptCommands != { } then
          pkgs.runCommandLocal "rig-prompt-commands-cc-plugin" { } ''
            mkdir -p $out/.claude-plugin $out/commands

            # Generate plugin manifest
            cat > $out/.claude-plugin/plugin.json <<'EOF'
            {
              "name": "rig",
              "description": "Prompt commands from rigup",
              "version": "0.0.0"
            }
            EOF

            # Generate command Markdown files
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (namespacedName: cmd: ''
                cat > $out/commands/${namespacedName}.md <<'CMDEOF'
                ---
                description: ${cmd.description}
                ${lib.optionalString cmd.useSubAgent "context: fork"}
                ---

                ${cmd.template}
                CMDEOF
              '') rig.promptCommands
            )}
          ''
        else
          null;
    in
    # Return a folder derivation with bin/ subfolder
    pkgs.writeShellScriptBin "claude" ''
      set -euo pipefail

      export PATH="${rig.toolRoot}/bin:$PATH"
      export RIG_DOCS="${rig.docRoot}"
      # For later reference, if needed
      export RIG_MANIFEST="${manifestPath}"

      exec ${pkgs.lib.getExe claude-code} \
        --append-system-prompt "$(cat ${manifestPath})" \
        --settings "${settingsJson}" \
        --mcp-config ${mcpConfig} \
        ${lib.optionalString config.claude-code.strictMcpConfig "--strict-mcp-config"} \
        ${lib.optionalString (pluginDir != null) "--plugin-dir ${pluginDir}"} \
        "$@"
    '';

  config.riglets.claude-code = {
    meta = {
      description = "Launch Claude Code with rig context";
      intent = "base";
      disclosure = "none";
      status = "stable";
      version = "0.1.0";
    };
  };
}
