# Inspect a specific rig and return detailed information about its structure
# Returns an attrset with riglets metadata and config options
rigupFlake:
{
  flake, # The flake containing the rig
  system, # Target system (e.g., "x86_64-linux")
  rigName, # Name of the rig to inspect
}:
let
  # Get the rig from the flake
  rig =
    if flake ? rigs && flake.rigs ? ${system} && flake.rigs.${system} ? ${rigName} then
      flake.rigs.${system}.${rigName}
    else
      builtins.throw "Rig '${rigName}' not found in flake for system '${system}'";

  # Extract riglets metadata from the rig
  rigletsData = rig.meta or { };

  # Extract config options from the rig (now exposed by buildRig)
  configOptions = rig.configOptions or { };

in
{
  name = rig.name or rigName;
  riglets = rigletsData;
  entrypoint = if rig ? "entrypoint" then rig.entrypoint.name else null;
  options = configOptions;
}
