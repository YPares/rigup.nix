_:
{ lib, ... }:
{
  options.models = {
    default = {
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
  };

  config.riglets.models.meta = {
    description = "Pre-select a specific model for a rig (To be used by entrypoints)";
    status = "stable";
    version = "0.1.0";
    intent = "base";
    disclosure = "none";
  };
}
