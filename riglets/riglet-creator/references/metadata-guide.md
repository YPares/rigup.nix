# Documentation Quality Checklist

Before publishing a riglet's documentation:

## Content Coverage

- [ ] **SKILL.md exists** with clear overview
- [ ] **Primary workflows documented** (3-5 core use cases)
- [ ] **Concrete examples throughout** - actual commands and output
- [ ] **No unexplained jargon** - domain terms are defined or linked
- [ ] **Links to references natural** (not exhaustive listing)

## Organization & Structure

- [ ] **SKILL.md is concise** (~100-150 lines max)
- [ ] **Complex topics in references** (not in SKILL.md)
- [ ] **Reference files have TOC** if longer than 100 lines
- [ ] **Clear file names** (advanced.md, troubleshooting.md, etc.)
- [ ] **One level deep references** - all links from SKILL.md, not between references

## Writing Quality

- [ ] **Imperative/infinitive form** ("Use tool X" not "This riglet uses")
- [ ] **Step-by-step when procedural** (numbered lists with expected output)
- [ ] **Examples show real output** where helpful
- [ ] **Tool warnings/limitations mentioned** if relevant
- [ ] **Related workflows cross-linked** (e.g., "For bulk ops, see...")

## Technical Accuracy

- [ ] **No tool errors in examples** (actually tested)
- [ ] **All mentioned tools exist in the rig** (in `tools = [ ]`)
- [ ] **All reference links valid** (files exist, paths relative)
- [ ] **Configuration examples correct** (if any provided)

## Reference Design

- [ ] **Troubleshooting reference** (if users commonly hit problems)
- [ ] **Advanced patterns reference** (if basics + advanced split makes sense)
- [ ] **Checklists/templates** (if helpful for the workflow)
- [ ] **Each reference focuses** on one topic (not kitchen-sink)

## Before Declaring Complete

Test the riglet in a real rig:

```bash
# Add to rigup.toml
[rigs.default.riglets]
self = ["my-riglet"]

# Build
nix build .#rigs.x86_64-linux.default.home

# Read documentation
cat result/docs/my-riglet/SKILL.md
cat result/docs/my-riglet/references/*.md

# Try workflows from SKILL.md
```

Ask: "If I were an agent, would I understand how to do the workflows described?"

