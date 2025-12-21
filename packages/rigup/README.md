# rigup CLI

Command-line tool for managing rigup rigs.

## Commands

### `rigup build [RIG]`

Build a rig's home directory.

```bash
# Build the default rig
rigup build

# Build a specific rig
rigup build my-rig
```

The rig will be built to `.rigup/<rig>/` in the current directory.

### `rigup shell [RIG] [--command CMD]`

Enter a development shell for a rig.

```bash
# Enter shell for default rig
rigup shell

# Enter shell for specific rig
rigup shell my-rig

# Run a command in the rig shell
rigup shell --command "jj status"
rigup shell my-rig --command "echo hello"
```

### `rigup list inputs`

List all flake inputs that expose riglets with their metadata.

```bash
rigup list inputs
```

This will show:
- Input name
- Available riglets
- Riglet descriptions, versions, status, and keywords

## Installation

The rigup CLI is available as a package in the rigup.nix flake:

```bash
# Install directly
nix profile install github:YPares/rigup.nix#rigup

# Or use in a shell
nix shell github:YPares/rigup.nix#rigup
```

## System Detection

The CLI automatically detects your current system (e.g., `x86_64-linux`, `aarch64-darwin`) and uses it to construct the appropriate flake references.
