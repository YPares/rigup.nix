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

    configFiles = riglib.writeFileTree {
      git."config" = pkgs.writeText "gitconfig" ''
        [user]
        	name = ${config.agent.identity.name}
        	email = ${config.agent.identity.email}
      '';
    };

    promptCommands = {
      healthcheck = {
        template = ''
          Perform a git healthcheck to make sure everything is in order:
          - Check that remotes are fetcheable
          - Check that no oversized file is currently under version control (unless git-lfs is properly in place)
          - Check that no commit is left dangling

          If not, reports problems and suggest solutions to the user
        '';
        description = "Git healtcheck";
      };
    };
  };
}
