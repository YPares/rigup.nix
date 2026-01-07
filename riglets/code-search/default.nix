_:
{
  pkgs,
  riglib,
  ...
}:
{
  config.riglets.code-search = {
    tools = with pkgs; [
      ripgrep
      fd
      bat
      fzf
      tree
    ];

    meta = {
      intent = "toolbox";
      description = "Code search and file tree browsing utilities: ripgrep, fd, bat, fzf, tree";
      keywords = [
        "search"
        "grep"
        "ripgrep"
        "fd"
        "find"
        "bat"
        "fzf"
        "tree"
        "file-browsing"
      ];
      status = "stable";
      version = "0.1.0";
    };

    docs = riglib.writeFileTree {
      "SKILL.md" = ./SKILL.md;
    };
  };
}
