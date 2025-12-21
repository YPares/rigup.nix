# Discover all riglets from all flake inputs
# Returns an attrset: { <input-name> = { <riglet-name> = <metadata>; ... }; ... }
rigupFlake:
{
  flake, # The current project's flake
  system, # Target system (e.g., "x86_64-linux")
}:
let
  # Get nixpkgs from the flake
  pkgs = flake.inputs.nixpkgs.legacyPackages.${system};

  # Process a single input to extract its riglets
  processInput =
    inputName: input:
    if input ? riglets && builtins.isAttrs input.riglets then
      let
        # Build a temporary rig with all riglets from this input
        tempRig = rigupFlake.lib.buildRig {
          name = "temp-discovery-${inputName}";
          inherit pkgs;
          modules = builtins.attrValues input.riglets;
        };
      in
      {
        "${inputName}" = tempRig.meta;
      }
    else
      { };

in
# Map over all inputs and collect riglet metadata
pkgs.lib.concatMapAttrs processInput ({ self = flake; } // flake.inputs)
