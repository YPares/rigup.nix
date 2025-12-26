# Agent Harness Integration

The rig system integrates with common AI coding agent harnesses via specialized riglets that define an "entrypoint": a wrapper script launched by `rigup run .#rig`.

## Implemented Integrations

### Claude Code (`claude-code-entrypoint`)

The `claude-code-entrypoint` riglet provides integration with Claude Code, the official Anthropic CLI tool. When included in a rig, it:

- Sets up `$PATH`, `$XDG_CONFIG_HOME`, and `$RIG_DOCS` environment variables with the rig's context
- Generates Claude Code settings that automatically display the RIG manifest on startup
- Allows launching Claude Code with full access to rig tools and documentation

This is the recommended way to use rigs with Claude Code.

## Planned Integrations

`rigup` is planned to provide similar integrations for common coding agent harnesses such as:

- `cursor-agent`
- `copilot-cli`
- Mistral's `vibe`

These harnesses and others are already Nix-packaged in numtide's [llm-agents.nix flake](https://github.com/numtide/llm-agents.nix) (previously called "nix-ai-tools").

The `claude-code-entrypoint` riglet serves as a reference for users and agents wishing to integrate with other harnesses.
