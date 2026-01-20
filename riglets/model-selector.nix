_:
{ lib, ... }:
{
  options.model-selector = {
    providerId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Model provider ID. Can be ignored depending on the entrypoint";
      default = null;
    };
    modelId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Model ID";
      default = null;
    };
  };

  config.riglets.model-selector.meta = {
    description = "Pre-select a specific model for a rig (To be used by entrypoints)";
    status = "stable";
    version = "0.1.0";
    intent = "base";
    disclosure = "none";
  };
}
