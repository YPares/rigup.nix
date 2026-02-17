_:
{ lib, config, ... }:
with lib.types;
let
  cfg = config.models;

  providerId = lib.mkOption {
    type = nullOr str;
    description = "Model provider ID. Can be ignored depending on the entrypoint";
    default = cfg.providers.default;
  };

  modelId = lib.mkOption {
    type = nullOr str;
    description = "Model ID";
    default = null;
  };

  providerAndModel = {
    inherit providerId modelId;
  };
in
{
  options.models = {
    default = providerAndModel;

    specialized = lib.mkOption {
      type = types.attrsOf (types.submodule { options = providerAndModel; });
      description = "Model overrides for specialized agents (plan, build, explore, etc.). Support depends on entrypoint";
      default = { };
    };

    providers = {
      default = lib.mkOption {
        type = nullOr str;
        description = "Default model provider to use";
        default = null;
      };

      disabled = lib.mkOption {
        description = "Prevent these providers from being used";
        type = nullOr (listOf str);
        default = [ ];
      };

      enabled = lib.mkOption {
        description = "Only allow these providers to be used. Allow all if null";
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
