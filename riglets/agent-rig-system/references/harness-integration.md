# Agent Harness Integration

The rig system integrates with common AI coding agent harnesses via specialized riglets that define an "entrypoint": a wrapper script launched by `rigup run .#rig`.

## Implemented Integrations

These harnesses and others are already Nix-packaged in numtide's [llm-agents.nix flake](https://github.com/numtide/llm-agents.nix) (previously called "nix-ai-tools").

The `claude-code` riglet serves as a reference for users and agents wishing to integrate with other harnesses.

### Claude Code

The `claude-code` riglet provides integration with Claude Code, the official Anthropic CLI tool.
Rig's configuration is generated and passed to Claude Code via CLI flags, and adds up to user's and project's pre-existing configuration.
All features of the riglet schema are supported.

### OpenCode

The `opencode` riglet provides integration with OpenCode.
Rig's configuration is generated and passed to OpenCode via env vars, and adds up to user's and project's pre-existing configuration.
All features of the riglet schema are supported.

### Cursor IDE & `cursor-agent`

The `cursor` riglet provides integration with Cursor IDE and `cursor-agent`.
It works by writing to the `.cursor/` folder of the user's project, as Cursor has no CLI flags or env vars that can be used to feed it external config.
Most features of the riglet schema are supported.

### `copilot-cli`

The `copilot-cli` riglet provides integration with GitHub `copilot-cli`.
Rig's manifest is shared with copilot-cli via env vars.
MCP servers and prompt commands are not supported. A warning will be displayed if the user's rig contains any MCP server config or prompt commands.

### VSCode + GitHub Copilot

The `vscode-copilot` riglet provides integration with VSCode and the GitHub Copilot extension.
It works by writing configuration files to the `.vscode/` and `.github/` folders of the user's project, as VSCode Copilot discovers these files automatically.
This is a setup-only riglet (no launch wrapper) - after running `rigup run .#rig`, users open their project with `code .` as usual.

**Key features:**
- Rig manifest copied to `.github/copilot-instructions.md` (auto-discovered by Copilot)
- MCP servers written to `.vscode/mcp.json` using VSCode format (`servers` key, not `mcpServers`)
- Prompt commands written to `.github/prompts/*.prompt.md` with YAML frontmatter
- Terminal auto-approve rules merged into `.vscode/settings.json` (preserves existing user settings)
- Documentation copied to `.github/rig-docs/` (symlinks don't work - VSCode blocks read access outside workspace)
- Activation script at `.github/rig-activate.sh` for PATH setup

**Limitations:**
- VSCode Copilot's `read_file` tool is workspace-scoped with no mechanism to grant access to external paths like Nix store
- Symlinks are resolved and then blocked if they point outside the workspace
- Therefore, rig docs must be copied into workspace (increases disk usage compared to symlink-based approaches)
- Settings merge uses `jq` - only touches `chat.tools.terminal.autoApprove` key to avoid disrupting user configuration

All features of the riglet schema are supported.

