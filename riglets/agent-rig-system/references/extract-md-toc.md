# extract-md-toc

A CLI tool to extract table of contents from markdown files.

## Features

- Extracts all heading levels
- Correctly ignores headings inside code blocks
- Preserves inline formatting in heading text (bold, italic, inline code)
- Outputs headings with line numbers

## Usage

```bash
# Extract all heading levels from a file
extract-md-toc path/to/file.md

# Extract only levels 1-3
extract-md-toc --max-level 3 path/to/file.md

# Read from stdin
cat file.md | extract-md-toc -

# Show help
extract-md-toc --help
```

## Output Format

The tool outputs entries with their line numbers:

```
Line 1: # Main Title
Line 2: ## Section One
Line 9: ### Subsection 1.1
...
```

## Implementation Notes

This tool uses a proper CommonMark parser ([pulldown-cmark](https://github.com/pulldown-cmark/pulldown-cmark)) which:

- Understands markdown structure (code blocks, inline formatting, etc.)
- Provides accurate line numbers via source offsets
- Handles all edge cases correctly
