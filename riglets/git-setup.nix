self:
{
  config,
  pkgs,
  riglib,
  lib,
  ...
}:
{
  imports = [ self.riglets.agent-identity ];

  config.riglets.git-setup = {
    tools = [ pkgs.git ];

    # Default set of deny rules for git usage
    # Using mkDefault means end users of this riglet will be able to override this
    denyRules.git = lib.mkDefault [
      "reset"
      "pull"
      "push"
      "commit --amend"
    ];

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
        description = "Git healtcheck";
        template = ''
          Perform a git healthcheck to make sure everything is in order:
          - Check that remotes are fetcheable
          - Check that no oversized file is currently under version control (unless git-lfs is properly in place)
          - Check that no commit is left dangling

          If not, report problems and suggest solutions to the user
        '';
      };
    };
  };
}
