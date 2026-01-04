self:
{
  riglib,
  ...
}:
{
  config.riglets.nixpkgs-manual = {
    meta = {
      mainDocFile = "manual.md.in";
      description = "The nixpkgs manual in riglet form";
      intent = "sourcebook";
      keywords = [
        "nix"
        "nixpkgs"
        "pkgs.lib"
        "nixpkgs.lib"
      ];
      whenToUse = [
        "Need to read nixpkgs general documentation"
        "Need to read up on functions provided by nixpkgs.lib"
      ];
      status = "experimental";
      inherit (self.inputs.nixpkgs.lib) version;
    };

    docs = riglib.filterFileTree [ "md" "md.in" ] "${self.inputs.nixpkgs}/doc";
  };
}
