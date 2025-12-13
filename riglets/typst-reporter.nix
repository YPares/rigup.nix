{ config, pkgs, lib, ... }:
{
  options.riglets.typst-reporter = lib.mkOption {
    type = lib.types.submodule {
      options = {
        template = lib.mkOption {
          type = lib.types.enum [ "academic" "technical" "simple" ];
          default = "simple";
          description = "Template style for generated reports";
        };

        tools = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ pkgs.typst pkgs.pandoc ];
        };

        docs = lib.mkOption {
          type = lib.types.package;
          default = pkgs.writeTextDir "SKILL.md" ''
            # Typst Report Generation

            ## Configuration

            - **Author**: ${config.user.name}
            - **Template**: ${config.riglets.typst-reporter.template}

            ## Quick Start

            Create a new report:

            ```bash
            cat > report.typ <<'EOF'
            #set document(author: "${config.user.name}")
            #set page(numbering: "1")

            = My Report

            _Author: ${config.user.name}_

            == Introduction

            This is a ${config.riglets.typst-reporter.template} report.

            == Findings

            Write your findings here.

            == Conclusion

            Summarize your work.
            EOF

            typst compile report.typ
            ```

            ## Template Styles

            ${lib.optionalString (config.riglets.typst-reporter.template == "academic") ''
            **Academic Template**:
            - Includes abstract
            - Bibliography support
            - Academic formatting (double-spaced, numbered sections)
            ''}

            ${lib.optionalString (config.riglets.typst-reporter.template == "technical") ''
            **Technical Template**:
            - Code highlighting
            - Diagram support
            - API documentation structure
            ''}

            ${lib.optionalString (config.riglets.typst-reporter.template == "simple") ''
            **Simple Template**:
            - Clean, minimal design
            - Quick turnaround
            - Good for short reports and memos
            ''}

            ## Common Patterns

            **Adding code blocks:**
            ````typst
            ```python
            def hello():
                print("world")
            ```
            ````

            **Including images:**
            ```typst
            #image("diagram.png", width: 80%)
            ```

            **Tables:**
            ```typst
            #table(
              columns: (auto, auto),
              [Name], [Value],
              [Result], [42]
            )
            ```

            ## Converting to Other Formats

            ```bash
            # Typst to PDF
            typst compile report.typ report.pdf
            # Then use your PDF viewer
            ```

            Your report is now tracked with author **${config.user.name}**.
          '';
        };
      };
    };
  };

  config.riglets.typst-reporter = {
    tools = [ pkgs.typst pkgs.pandoc ];
  };
}
