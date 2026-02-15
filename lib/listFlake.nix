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
          # Build one temp rig per riglet to extract its metadata in isolation
          builtins.mapAttrs (
            rigletName: rigletModule:
            let
              # Build a rig with only this riglet (and its imports if it has any)
              tempRig = rigupFlake.lib.buildRig {
                name = "tmp-rig";
                inherit pkgs;
                modules = [ rigletModule ];
              };
            in
            # Extract this riglet's metadata from the rig, and add entrypoint info
            (tempRig.meta.${rigletName} or { })
            // {
              entrypoint = if tempRig ? "entrypoint" then tempRig.entrypoint.name else null;
            }
          ) input.riglets
        else
          { };

      # Extract rigs metadata
      rigsData =
        if input ? rigs && input.rigs ? ${system} && builtins.isAttrs input.rigs.${system} then
          builtins.mapAttrs (rigName: rig: {
            riglets = rig.meta or { };
            entrypoint = if rig ? "entrypoint" then rig.entrypoint.name else null;
          }) input.rigs.${system}
        else
          { };
    in
    if rigletsData != { } || rigsData != { } then
      {
        "${inputName}" = {
          riglets = rigletsData;
          rigs = rigsData;
        };
      }
    else
      { };

  # Select which inputs to process
  inputsToProcess = {
    self = flake;
  }
  // pkgs.lib.optionalAttrs includeInputs flake.inputs;
in
# Map over selected inputs and collect metadata
pkgs.lib.concatMapAttrs processInput inputsToProcess
