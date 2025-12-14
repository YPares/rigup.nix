# My AI Agent Rig

This project uses [rigup](https://github.com/YPares/rigup.nix) to package AI agent skills with their tools and configuration.

## Quick Start

```bash
# Build your rig
nix build

# Explore the rig
cat result/RIG.md

# Use the tools
export PATH="$PWD/result/bin:$PATH"

# Read the documentation
cat result/docs/my-first-riglet/SKILL.md
```

## Project Structure

- `flake.nix` - Nix flake configuration
- `rigup.toml` - Rig definitions and configuration
- `riglets/` - Your riglet modules
  - `my-first-riglet.nix` - Example riglet (replace with your own)

## Next Steps

1. Edit `riglets/my-first-riglet.nix` to add your tools and documentation
2. Update `rigup.toml` to configure your rig
3. Add more riglets as needed
4. Build and test: `nix build`

## Learn More

- [rigup documentation](https://github.com/YPares/rigup.nix)
- [Claude Skills](https://code.claude.com/docs/en/skills)
- [Nix modules](https://nix.dev/tutorials/module-system/a-basic-module/)
