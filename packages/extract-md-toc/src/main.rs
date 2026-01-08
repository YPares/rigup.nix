use clap::Parser;
use pulldown_cmark::{Event, Options, Parser as MarkdownParser, Tag, TagEnd};
use std::fs;
use std::io::{self, Read, Write};

#[derive(Parser)]
#[command(name = "extract-md-toc")]
#[command(about = "Extract table of contents from markdown files with line numbers", long_about = None)]
struct Cli {
    /// Path to markdown file to parse, or '-' to read from stdin
    file: String,

    /// Only extract headers up to level N (>=1). Default: extract all levels
    #[arg(long, value_name = "N", value_parser = clap::value_parser!(u8).range(1..))]
    max_level: Option<u8>,
}

fn main() {
    let cli = Cli::parse();

    let content = if cli.file == "-" {
        let mut buffer = String::new();
        io::stdin()
            .read_to_string(&mut buffer)
            .expect("Failed to read from stdin");
        buffer
    } else {
        fs::read_to_string(&cli.file).unwrap_or_else(|err| {
            eprintln!("Error reading file '{}': {}", cli.file, err);
            std::process::exit(1);
        })
    };

    let stdout = io::stdout();
    let mut writer = stdout.lock();
    extract_toc_stream(&content, cli.max_level, &mut writer).expect("Failed to write output");
}

/// Stream TOC entries directly to a writer as they're discovered
fn extract_toc_stream<W: Write>(
    content: &str,
    max_level: Option<u8>,
    writer: &mut W,
) -> io::Result<()> {
    let mut options = Options::empty();
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_FOOTNOTES);
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TASKLISTS);
    options.insert(Options::ENABLE_YAML_STYLE_METADATA_BLOCKS);

    let parser = MarkdownParser::new_ext(content, options).into_offset_iter();
    let mut in_heading = false;
    let mut heading_start_offset: usize = 0;
    let mut heading_text = String::new();

    for (event, range) in parser {
        match event {
            Event::Start(Tag::Heading { level, .. }) => {
                // Check if this level should be extracted based on max_level filter
                let level_num = level as u8;
                let should_extract = max_level.map_or(true, |max| level_num <= max);

                if should_extract {
                    in_heading = true;
                    heading_start_offset = range.start;
                    heading_text.clear();

                    // Add the markdown heading prefix (#, ##, ###, etc.)
                    for _ in 0..level_num {
                        heading_text.push('#');
                    }
                    heading_text.push(' ');
                }
            }
            Event::End(TagEnd::Heading(_)) => {
                if in_heading {
                    let line_num = offset_to_line_number(content, heading_start_offset);
                    writeln!(writer, "Line {}: {}", line_num, heading_text)?;
                    in_heading = false;
                }
            }
            Event::Text(text) | Event::Code(text) => {
                if in_heading {
                    heading_text.push_str(&text);
                }
            }
            Event::SoftBreak | Event::HardBreak => {
                if in_heading {
                    heading_text.push(' ');
                }
            }
            _ => {}
        }
    }

    Ok(())
}

fn offset_to_line_number(content: &str, offset: usize) -> usize {
    // Count newlines before the offset
    let before_offset = &content[..offset.min(content.len())];
    before_offset.chars().filter(|&c| c == '\n').count() + 1
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Helper to capture output of extract_toc_stream as a string
    fn extract_to_string(content: &str, max_level: Option<u8>) -> String {
        let mut buffer = Vec::new();
        extract_toc_stream(content, max_level, &mut buffer).expect("Writing should not fail");
        String::from_utf8(buffer).expect("Output should be valid UTF-8")
    }

    #[test]
    fn test_offset_to_line_number() {
        let content = "line1\nline2\nline3\n";
        assert_eq!(offset_to_line_number(content, 0), 1);
        assert_eq!(offset_to_line_number(content, 6), 2);
        assert_eq!(offset_to_line_number(content, 12), 3);
    }

    #[test]
    fn test_extract_toc() {
        let markdown = r#"# Title
Some text
## Section 1
More text
### Subsection 1.1
## Section 2
"#;
        let output = extract_to_string(markdown, None);
        insta::assert_snapshot!(output, @r###"
        Line 1: # Title
        Line 3: ## Section 1
        Line 5: ### Subsection 1.1
        Line 6: ## Section 2
        "###);
    }

    #[test]
    fn test_extract_toc_with_max_level() {
        let markdown = "# Title\n## Section\n### Subsection\n";
        let output = extract_to_string(markdown, Some(2));
        // Should extract "# Title" and "## Section", but not "### Subsection"
        insta::assert_snapshot!(output, @r###"
        Line 1: # Title
        Line 2: ## Section
        "###);
    }

    #[test]
    fn test_yaml_frontmatter_not_treated_as_heading() {
        let markdown = r#"---
title: Test Document
author: Test Author
---

# Real Heading 1
## Real Heading 2
"#;
        let output = extract_to_string(markdown, None);
        // The YAML frontmatter delimiters (---) should not be treated as headings
        // Should only extract the real headings, not the frontmatter delimiters
        insta::assert_snapshot!(output, @r###"
        Line 6: # Real Heading 1
        Line 7: ## Real Heading 2
        "###);
    }
}
