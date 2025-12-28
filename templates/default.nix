{
  default = {
    path = ./default;
    description = "Basic rigup project with example riglet";
    welcomeText = ''
      # Project initialized!

      # Next steps

      1. Make sure the `rigup` CLI tool is installed and up to date (`nix profile add github:YPares/rigup.nix#rigup`)
      2. Edit `riglets/my-first-riglet.nix` to add your tools and documentation
      3. Edit `rigup.toml` to configure your rig
      4. Build your rig: `rigup build`
      5. See the output manifest for your AI agent: `cat .rigup/default/RIG.md`
      6. Learn more: `https://github.com/YPares/rigup.nix`
    '';
  };
  minimal = {
    path = ./minimal;
    description = "Minimal rigup project";
    welcomeText = ''
      # Project initialized!

      # Next steps

      1. Make sure the `rigup` CLI tool is installed and up to date (`nix profile add github:YPares/rigup.nix#rigup`)
      2. Edit `rigup.toml` to configure your rig
      3. Build your rig: `rigup build`
      4. See the output manifest for your AI agent: `cat .rigup/default/RIG.md`
      5. Learn more: `https://github.com/YPares/rigup.nix`
    '';
  };
}
