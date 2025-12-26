# extract-md-toc

A CLI tool to extract table of contents from markdown files with line numbers.

## Features

- Properly parses markdown using [pulldown-cmark](https://github.com/pulldown-cmark/pulldown-cmark)
- Extracts all heading levels (1-6)
- Correctly ignores headings inside code blocks
- Preserves inline formatting in heading text (bold, italic, inline code)
- Outputs XML format with line numbers

## Usage

```bash
# Extract all heading levels from a file
extract-md-toc path/to/file.md

# Extract only levels 1-2 (shallow TOC)
extract-md-toc --max-level 2 path/to/file.md

# Read from stdin
cat file.md | extract-md-toc -

# Show help
extract-md-toc --help
```

## Output Format

The tool outputs XML entries with line numbers:

```xml
<entry line="1"># Main Title</entry>
<entry line="5">## Section One</entry>
<entry line="9">### Subsection 1.1</entry>
```

## Building with Nix

```bash
# Build the package
nix build .#extract-md-toc

# Run directly
nix run .#extract-md-toc -- file.md
```

## Why This Tool?

The previous implementation used simple string matching which:
- Could match `##` in code blocks
- Didn't handle escaping properly
- Was fragile to edge cases

This tool uses a proper CommonMark parser that:
- Understands markdown structure (code blocks, inline formatting, etc.)
- Provides accurate line numbers via source offsets
- Handles all edge cases correctly
