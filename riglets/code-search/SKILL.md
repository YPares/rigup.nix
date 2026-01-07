# Code Search & File Tree Browsing

Fast, efficient utilities for searching code and browsing file hierarchies.

## Tools Overview

### ripgrep (rg)
Ultra-fast grep alternative that respects .gitignore by default.

**Common usage:**
```bash
rg <pattern> [<path>]              # Search for pattern in files
rg -t <type> <pattern>             # Search files of specific type
rg --no-ignore <pattern>           # Search ignoring .gitignore
rg -w <pattern>                    # Match whole word
rg -C <num> <pattern>              # Show context lines
```

### fd
Faster, simpler alternative to `find` with better defaults and colorized output.

**Common usage:**
```bash
fd <pattern> [<path>]              # Find files matching pattern
fd -e <ext> <pattern>              # Find by extension
fd -t f <pattern>                  # Find files only
fd -t d <pattern>                  # Find directories only
fd --follow <pattern>              # Follow symlinks
```

### bat
Syntax-highlighting cat with git integration and line numbers.

**Common usage:**
```bash
bat <file>                         # View file with syntax highlighting
bat --line-range <start:end> <file>  # Show specific line range
rg <pattern> | bat --file-name <path>  # Syntax highlight search results
```

### fzf
Fuzzy filtering and pattern matching for command pipelines.

**Common usage:**
```bash
<command> | fzf --filter <pattern>  # Filter output by pattern (non-interactive)
echo -e "file1\nfile2\nfile3" | fzf --filter "file"  # Match lines containing "file"
rg <pattern> | fzf --filter <secondary-pattern>  # Further filter search results
```

### tree
Display directory structure in tree format.

**Common usage:**
```bash
tree [<path>]                      # Show tree structure
tree -L <depth> [<path>]           # Limit depth
tree -I '<pattern>'                # Exclude pattern
tree -a                            # Include hidden files
```

## Common Workflows

### Filter search results by secondary pattern
```bash
rg <primary-pattern> | fzf --filter <secondary-pattern>
```

### Search code and show context
```bash
rg -C 3 <pattern>
```

### Search specific file types
```bash
rg -t ts <pattern>      # TypeScript files
rg -t py <pattern>      # Python files
rg -t go <pattern>      # Go files
```

### List directory tree
```bash
tree -L 3
```
