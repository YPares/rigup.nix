{
  config,
  pkgs,
  inputs,
  riglib,
  ...
}:
{
  config.riglets.my-first-riglet = {
    # Metadata for your agent
    meta = {
      name = "My First Riglet";
      description = "Example riglet to get you started";
      whenToUse = [
        "When this riglet will no longer be a draft"
      ];
      keywords = [
        "example"
        "tutorial"
      ];
      status = "draft";
      version = "0.1.0";
    };

    # Tools needed by this riglet
    tools = [
      # pkgs.mytool
    ];

    # Tool configuration (optional)
    # config-files = riglib.writeFileTree {
    #   mytool."config.toml" = ''
    #     setting = "value"
    #   '';
    # };

    # Documentation
    docs = riglib.writeFileTree {
      "SKILL.md" = ''
        # My First Riglet

        ## Overview

        This is an example riglet. Replace this with your own documentation.

        ## Quick Reference

        ```bash
        # Add your commands here
        echo "Hello from my riglet!"
        ```

        ## Key Concepts

        - Edit this riglet to add your own tools and documentation
        - Use riglib.writeFileTree to organize docs
        - Configure tools via config-files

        ## Next Steps

        1. Add tools to the `tools` list
        2. Update the metadata
        3. Write your documentation
        4. Add config-files if needed
      '';
    };
  };
}
