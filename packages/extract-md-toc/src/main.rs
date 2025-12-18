use pulldown_cmark::{Event, Options, Parser, Tag, TagEnd};
use std::env;
use std::fs;
use std::io::{self, Read};
use std::process;

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("Usage: {} [OPTIONS] <file|-|--help>", args[0]);
        eprintln!("  file: Path to markdown file");
        eprintln!("  -: Read from stdin");
        eprintln!("  --help: Show this help");
        eprintln!("\nOptions:");
        eprintln!("  --max-level N: Only extract headers up to level N (1-6)");
        process::exit(1);
    }

    if args[1] == "--help" {
        println!("extract-md-toc - Extract table of contents from markdown files");
        println!("\nUsage: {} [OPTIONS] <file|->", args[0]);
        println!("\nOptions:");
        println!("  --max-level N  Only extract headers up to level N (1-6). Default: extract all levels");
        println!("\nArguments:");
        println!("  file           Path to markdown file to parse");
        println!("  -              Read from stdin");
        println!("\nOutput format:");
        println!("  Generates XML with headers and line numbers:");
        println!("  <entry line=\"5\">## Header Text</entry>");
        return;
    }

    // Parse arguments
    let mut max_level: Option<u8> = None;
    let mut file_arg: Option<String> = None;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--max-level" => {
                if i + 1 >= args.len() {
                    eprintln!("Error: --max-level requires a value");
                    process::exit(1);
                }
                max_level = Some(args[i + 1].parse().unwrap_or_else(|_| {
                    eprintln!("Error: --max-level must be a number between 1 and 6");
                    process::exit(1);
                }));
                if max_level.unwrap() < 1 || max_level.unwrap() > 6 {
                    eprintln!("Error: --max-level must be between 1 and 6");
                    process::exit(1);
                }
                i += 2;
            }
            arg => {
                file_arg = Some(arg.to_string());
                i += 1;
            }
        }
    }

    let file = file_arg.unwrap_or_else(|| {
        eprintln!("Error: No input file specified");
        process::exit(1);
    });

    let content = if file == "-" {
        let mut buffer = String::new();
        io::stdin()
            .read_to_string(&mut buffer)
            .expect("Failed to read from stdin");
        buffer
    } else {
        fs::read_to_string(&file).unwrap_or_else(|err| {
            eprintln!("Error reading file '{}': {}", file, err);
            process::exit(1);
        })
    };

    extract_toc(&content, max_level);
}

fn extract_toc(content: &str, max_level: Option<u8>) {
    let mut options = Options::empty();
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_FOOTNOTES);
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TASKLISTS);

    let parser = Parser::new_ext(content, options).into_offset_iter();
    let mut entries = Vec::new();
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
                    entries.push((line_num, heading_text.clone()));
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

    // Output entries
    for (line_num, text) in entries {
        println!("Line {}: {}", line_num, text);
    }
}

fn offset_to_line_number(content: &str, offset: usize) -> usize {
    // Count newlines before the offset
    let before_offset = &content[..offset.min(content.len())];
    before_offset.chars().filter(|&c| c == '\n').count() + 1
}

#[cfg(test)]
mod tests {
    use super::*;

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
        extract_toc(markdown, None);
        // This will print to stdout, but we can verify it doesn't panic
    }

    #[test]
    fn test_extract_toc_with_max_level() {
        let markdown = "# Title\n## Section\n### Subsection\n";
        extract_toc(markdown, Some(2));
        // Should extract "# Title" and "## Section", but not "### Subsection"
    }
}
