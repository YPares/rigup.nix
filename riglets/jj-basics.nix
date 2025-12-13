{
  config,
  pkgs,
  lib,
  riglib,
  ...
}:
{
  # Define shared options at top level
  options.agent.user = {
    name = lib.mkOption {
      type = lib.types.str;
      example = "AI-Agent";
      description = "AI Agent's username for version control and documentation";
    };

    email = lib.mkOption {
      type = lib.types.str;
      example = "foo@bar.qux";
      description = "AI Agent's email address (can be fake)";
    };
  };

  config.riglets.jj-basics = {
    tools = [ pkgs.jujutsu ];

    meta = {
      name = "JJ Basics";
      description = "Jujutsu version control fundamentals and workflows";
      whenToUse = [
        "Working with version control"
        "Managing changes and commits"
        "Navigating change history"
        "Collaborating on code"
      ];
      keywords = [
        "jj"
        "jujutsu"
        "version-control"
        "vcs"
        "git"
        "dvcs"
      ];
    };

    docs = riglib.writeDocsTree {
      files = {
        SKILL = ''
          # JJ Basics

          ## Quick Reference

          Configured for: **${config.agent.user.name}** <${config.agent.user.email}>

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
          name = "${config.agent.user.name}"
          email = "${config.agent.user.email}"
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
        '';

        references.revsets = ''
          # Advanced: JJ Revsets

          Revsets are a powerful query language for selecting changes.

          ## Common Patterns

          - `@` - Current change (working copy)
          - `@-` - Parent of current change
          - `main..@` - All changes between main and current
          - `description(foo)` - Changes with "foo" in description
          - `author(alice)` - Changes by alice

          ## Combining Revsets

          - `a | b` - Union (a OR b)
          - `a & b` - Intersection (a AND b)
          - `a ~ b` - Difference (a but not b)

          ## Practical Examples

          **See all your uncommitted work:**
          ```bash
          jj log -r 'mine() & ~remote_branches()'
          ```

          **Find changes mentioning a bug:**
          ```bash
          jj log -r 'description(bug-123)'
          ```
        '';
      };
    };
  };
}
