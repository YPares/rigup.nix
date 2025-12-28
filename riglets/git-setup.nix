self:
{
  config,
  pkgs,
  riglib,
  ...
}:
{
  imports = [ self.riglets.agent-identity ];

  config.riglets.git-setup = {
    tools = [ pkgs.git ];

    meta = {
      description = "Git setup with agent-identity";
      intent = "base";
      keywords = [
        "git"
        "version-control"
        "vcs"
        "dvcs"
      ];
      status = "stable";
      version = "0.1.0";
      disclosure = "none";
    };

    config-files = riglib.writeFileTree {
      git."config" = pkgs.writeText "gitconfig" ''
        [user]
        	name = ${config.agent.identity.name}
        	email = ${config.agent.identity.email}
      '';
    };
  };
}
