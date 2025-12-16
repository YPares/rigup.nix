_:
{
  config,
  pkgs,
  lib,
  riglib,
  ...
}:
{
  options.typst = {
    template = lib.mkOption {
      type = lib.types.enum [
        "academic"
        "technical"
        "simple"
      ];
      default = "simple";
      description = "Template style for generated reports";
    };
  };

  config.riglets.typst-reporter = {
    tools = [
      pkgs.typst
      pkgs.pandoc
    ];

    meta = {
      name = "Typst Reporter";
      description = "Generate professional reports and documents using Typst";
      whenToUse = [
        "Creating reports or documentation"
        "Generating PDFs from markup"
        "Formatting technical documents"
        "Converting between document formats"
      ];
      keywords = [
        "typst"
        "pandoc"
        "pdf"
        "reports"
        "documentation"
        "markup"
      ];
      status = "example";
      version = "0.1.0";
    };

    config-files = riglib.writeFileTree {
      typst."template.typ" = ''
        // Default ${config.typst.template} template for ${config.agent.user.name}
        #set document(author: "${config.agent.user.name}")
        #set page(numbering: "1")

        = Report Title

        By ${config.agent.user.name}

        == Section

        Your content here.
      '';
    };

    docs = riglib.writeFileTree {
      "SKILL.md" = ''
        # Typst Report Generation

        ## Quick Start

        Create a new report:

        ```bash
        cat > report.typ <<'EOF'
        #set document(author: "${config.agent.user.name}")
        #set page(numbering: "1")

        = My Report

        By ${config.agent.user.name} (_${config.agent.user.email}_)

        == Introduction

        This is a ${config.typst.template} report.

        == Findings

        Write your findings here.

        == Conclusion

        Summarize your work.
        EOF

        typst compile report.typ
        ```

        ## Template Styles

        ${lib.optionalString (config.typst.template == "academic") ''
          **Academic Template**:
          - Includes abstract
          - Bibliography support
          - Academic formatting (double-spaced, numbered sections)
        ''}

        ${lib.optionalString (config.typst.template == "technical") ''
          **Technical Template**:
          - Code highlighting
          - Diagram support
          - API documentation structure
        ''}

        ${lib.optionalString (config.typst.template == "simple") ''
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
      '';
    };
  };
}
