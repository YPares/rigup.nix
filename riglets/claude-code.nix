self:
{
  pkgs,
  system,
  lib,
  config,
  ...
}:
let
  inherit (self.inputs.llm-agents.packages.${system}) claude-code;
in
{
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

      settingsJson = (pkgs.formats.json { }).generate "${rig.name}-settings.json" {
        # Grant read access to specific Nix store paths that Claude Code needs
        permissions.allow = [
          "Read(${manifestPath})" # The RIG.md manifest file
          "Read(${rig.docRoot}/**)" # All documentation files
          "Read(${rig.configRoot}/**)" # All config files
          "Read(${rig.toolRoot}/**)" # Tool files (for inspecting share/, lib/, etc.)
        ]
        ++ map (cmd: "Bash(${cmd}:*)") rig.allExeNames; # Allow executing all rig tools
      };

      mcpConfig = (pkgs.formats.json { }).generate "${rig.name}-mcp-config.json" {
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
