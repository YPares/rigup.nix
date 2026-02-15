_:
{ lib, ... }:
{
  options.models = with lib.types; {
    default = {
      providerId = lib.mkOption {
        type = nullOr str;
        description = "Model provider ID. Can be ignored depending on the entrypoint";
        default = null;
      };
      modelId = lib.mkOption {
        type = nullOr str;
        description = "Model ID";
        default = null;
      };
    };

    providers = {
      disabled = lib.mkOption {
        description = "Prevent these providers from being used";
        type = nullOr (listOf str);
        default = null;
      };

      enabled = lib.mkOption {
        description = "Only allow these providers to be used";
        type = nullOr (listOf str);
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
