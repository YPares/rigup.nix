_:
{ lib, ... }:
let
  providerAndModel = with lib.types; {
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
in
{
  options.models = with lib.types; {
    default = providerAndModel;

    specialized = lib.mkOption {
      type = types.attrsOf (types.submodule { options = providerAndModel; });
      description = "Model overrides for specialized agents (plan, build, explore, etc.). Support depends on entrypoint";
      default = { };
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
    description = "Pre-select model(s) for a rig (to be imported by compatible entrypoints)";
    status = "stable";
    version = "0.1.0";
    intent = "base";
    disclosure = "none";
  };
}
