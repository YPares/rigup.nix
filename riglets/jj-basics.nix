{ config, pkgs, lib, ... }:
{
  # Define shared user options at top level
  options.user = {
    name = lib.mkOption {
      type = lib.types.str;
      example = "Alice Developer";
      description = "User's full name for version control and documentation";
    };

    email = lib.mkOption {
      type = lib.types.str;
      example = "alice@example.com";
      description = "User's email address (can be fake for agent use)";
    };
  };

  config.riglets.jj-basics = {
    tools = [ pkgs.jujutsu ];

    docs = pkgs.writeTextDir "SKILL.md" ''
            # JJ Basics

            ## Quick Reference

            Configured for: **${config.user.name}** <${config.user.email}>

            ### Essential Commands

            ```bash
            jj log            # View change history
            jj st             # Current change status
            jj new            # Create new change
            jj describe       # Edit change description
            jj diff           # See what changed
            ```

            ### Making Changes

            1. Edit files as needed
            2. `jj describe` - describe your change
            3. `jj new` - start next change (commits previous)

            ### Key Concepts

            - **Working copy**: Your current change (always @ in log)
            - **Change**: A snapshot of your work
            - **Description**: Message for the change
            - No staging area - just edit and commit

            ### Configuration

            Your JJ config should include:

            ```toml
            [user]
            name = "${config.user.name}"
            email = "${config.user.email}"
            ```

            ### Workflow Tips

            - Use `jj new` frequently to create clean change boundaries
            - Describe changes as you go, not at the end
            - `jj log` is your friend - use it often
            - No need for branches for simple workflows

            ### Common Tasks

            **Undo last operation:**
            ```bash
            jj op undo
            ```

            **See what will be committed:**
            ```bash
            jj diff
            ```

            **Edit earlier change:**
            ```bash
            jj edit <change-id>
            # Make edits
            jj new  # Return to tip
            ```

            For more advanced workflows, see the full `working-with-jj` skill.
    '';
  };
}
