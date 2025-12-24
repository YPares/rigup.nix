# Discover all riglets and rigs from flake & inputs
# Returns an attrset: { <input-name> = { riglets = { <riglet-name> = <metadata>; ... }; rigs = { <rig-name> = <metadata>; ... }; }; ... }
rigupFlake:
{
  flake, # The current project's flake
  system, # Target system (e.g., "x86_64-linux")
  includeInputs ? false, # Whether to include flake inputs or just self
}:
let
  # Get nixpkgs from the flake
  pkgs = flake.inputs.nixpkgs.legacyPackages.${system};

  # Process a single input to extract its riglets and rigs
  processInput =
    inputName: input:
    let
      # Extract riglets metadata
      rigletsData =
        if input ? riglets && builtins.isAttrs input.riglets then
          let
            # Build a temporary rig with all riglets from this input
            tempRig = rigupFlake.lib.buildRig {
              name = "temp-discovery-${inputName}";
              inherit pkgs;
              modules = builtins.attrValues input.riglets;
            };
          in
          tempRig.meta
        else
          { };

      # Extract rigs metadata
      rigsData =
        if input ? rigs && input.rigs ? ${system} && builtins.isAttrs input.rigs.${system} then
          builtins.mapAttrs (rigName: rig: rig.meta or { }) input.rigs.${system}
        else
          { };

      hasData = rigletsData != { } || rigsData != { };
    in
    if hasData then
      {
        "${inputName}" = {
          riglets = rigletsData;
          rigs = rigsData;
        };
      }
    else
      { };

  # Select which inputs to process
  inputsToProcess = if includeInputs then ({ self = flake; } // flake.inputs) else { self = flake; };

in
# Map over selected inputs and collect metadata
pkgs.lib.concatMapAttrs processInput inputsToProcess
