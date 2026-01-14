# Inspect a specific rig and return detailed information about its structure
# Returns an attrset with riglets metadata and config options
rigupFlake:
{
  flake, # The flake containing the rig
  system, # Target system (e.g., "x86_64-linux")
  rigName, # Name of the rig to inspect
}:
let
  rig =
    flake.rigs.${system}.${rigName}
      or (throw "Rig '${rigName}' not found in flake for system ${system}");
in
{
  name = rig.name or rigName;
  riglets = rig.meta or { };
  entrypoint = rig.entrypoint.name or null;
  options = rig.configOptions or { };
}
