_:
{ pkgs, config, ... }:
let
  readonlyCmds = [
    "["
    "ls"
    "cat"
    "head"
    "tail"
    "wc"
    "cut"
    "sort"
    "uniq"
    "date"
    "basename"
    "dirname"
    "pwd"
    "echo"
    "printf"
    "true"
    "false"
    "yes"
    "seq"
    "tr"
    "tee"
    "tac"
    "nl"
    "od"
    "paste"
    "base64"
    "base32"
    "basenc"
    "b2sum"
    "cksum"
    "md5sum"
    "sha1sum"
    "sha224sum"
    "sha256sum"
    "sha384sum"
    "sha512sum"
    "sum"
    "readlink"
    "realpath"
    "stat"
    "du"
    "df"
    "whoami"
    "id"
    "groups"
    "users"
    "who"
    "pinky"
    "logname"
    "hostid"
    "uptime"
    "test"
    "expr"
    "factor"
    "numfmt"
    "pathchk"
    "printenv"
    "env"
    "fmt"
    "fold"
    "join"
    "pr"
    "ptx"
    "comm"
    "csplit"
    "expand"
    "unexpand"
    "split"
    "tsort"
    "dir"
    "vdir"
  ];

  mkFilteredCoreutils =
    commands:
    pkgs.runCommand "coreutils-filtered" { } ''
      mkdir -p $out/bin
      for cmd in ${pkgs.lib.concatStringsSep " " commands}; do
        if [ -f ${pkgs.coreutils}/bin/$cmd ]; then
          ln -s ${pkgs.coreutils}/bin/$cmd $out/bin/
        else
          echo "ERROR: coreutils does not contain '$cmd'" >&2
          exit 1
        fi
      done
    '';
in
{
  options.coreutils.commands =
    with pkgs.lib;
    mkOption {
      description = "Which coreutils commands to include and allow";
      type = types.oneOf [
        (types.enum [
          "all"
          "readonly"
        ])
        (types.listOf types.str)
      ];
      # By default: only read-only commands
      default = "readonly";
    };

  config.riglets.coreutils = {
    # These don't read config, so they don't need to be wrapped
    # (build will be faster)
    tools.unwrapped = [
      (
        if config.coreutils.commands == "all" then
          pkgs.coreutils
        else if config.coreutils.commands == "readonly" then
          mkFilteredCoreutils readonlyCmds
        else
          mkFilteredCoreutils config.coreutils.commands
      )
    ];
    meta = {
      intent = "base";
      disclosure = "none";
      status = "stable";
      version = "0.1.0";
      description = "ls, cat, wc, etc. commands, so the rig's entrypoint may be pre-configured to allow them all";
      keywords = [
        "coreutils"
        "ls"
        "cat"
        "printf"
        "wc"
        "shell"
      ];
    };
  };
}
