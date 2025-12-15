{
  default = {
    path = ./default;
    description = "Basic rigup project with example riglet";
    welcomeText = ''
      # Project initialized!

      # Next steps

      1. Edit riglets/my-first-riglet.nix to add your tools and documentation
      2. Update rigup.toml to configure your rig
      3. Build your rig: nix build
      4. Explore the output: cat result/RIG.md
      5. Learn more: https://github.com/YPares/rigup.nix
    '';
  };
  minimal = {
    path = ./minimal;
    description = "Minimal rigup project";
    welcomeText = ''
      # Project initialized!

      # Next steps

      1. Update rigup.toml to configure your rig
      2. Build your rig: nix build
      3. Explore the output: cat result/RIG.md
      4. Learn more: https://github.com/YPares/rigup.nix
    '';
  };
}
