# Riglet Creator

Creating effective riglets means writing knowledge (SKILL.md) that agents will rely on. This guide focuses on how to write high-quality documentation for riglets, organized efficiently.

For the structural/technical side of riglets (what goes in the Nix module, metadata fields, schema), see **agent-rig SKILL.md**.

## Core Principles

### Concise is Key

Agents share context windows with conversation history, system instructions, and other riglets in the rig. Context is a shared resource.

**Default assumption: Agents are already very capable.** Only include knowledge agents don't already have. Challenge each piece of information: "Does the agent really need this explanation?" and "Does this paragraph justify its token cost?"

Prefer concrete examples over verbose explanations. Prefer links to references over embedding everything in SKILL.md.

### Set Appropriate Degrees of Freedom

Match documentation specificity to the task's fragility and variability:

**High freedom (general guidance)**: Use when multiple approaches are valid, decisions depend on context, or heuristics guide the process. Example: "Organizing commits in JJ" — many strategies work.

**Medium freedom (documented patterns with options)**: Use when a preferred pattern exists but some variation is acceptable. Example: "Creating PDFs with Typst" — follow the basic template but customize styling.

**Low freedom (specific procedures, few choices)**: Use when operations are fragile and error-prone, consistency is critical, or a specific sequence must be followed. Example: "Setting up encrypted credentials" — must follow exact steps.

Think of it as a path: a narrow bridge with cliffs needs specific guardrails (low freedom, detailed steps), while an open field allows many routes (high freedom, general principles).

### Structure: Know What Goes Where

Riglets have different components for different purposes:

**SKILL.md** - Primary workflows and procedures
- What: Core knowledge agents load first
- When: Procedures, common workflows, decision trees
- Length: ~100-150 lines ideally
- Load cost: Loaded for every interaction

**references/** - Deep knowledge, advanced topics
- What: Advanced patterns, troubleshooting, detailed specifications
- When: Complex scenarios, edge cases, detailed reference material
- Length: 50-200 lines each, with TOC if >100
- Load cost: Only loaded when agent determines it's needed

**tools in Nix** - Executable packages
- What: CLI tools, compilers, interpreters needed by the riglet
- When: When the riglet teaches workflows that use specific tools
- Load cost: Built into rig environment, always available

Keep information in one place: SKILL.md or references, not both. Prefer references for detailed material unless it's core to the riglet—this keeps SKILL.md lean and makes information discoverable without hogging context.

## Understanding the Riglet with Concrete Examples

Skip this step only when the riglet's patterns are already clearly understood.

Before writing a riglet, deeply understand what it will teach. Concrete examples drive effective documentation.

To create an effective riglet, clarify the scope with concrete examples:

- "What workflows does this riglet enable?"
- "What are realistic use cases?"
- "What problems does it solve?"
- "What would agents ask for that this riglet answers?"

For example, when building a riglet about version control with JJ:
- What functionality should it cover? (Creating changes, managing history, collaboration?)
- Can you give concrete examples? ("I need to reorganize my commits" or "I'm collaborating with git users")
- What would an agent say that should trigger this riglet?

To avoid overwhelming agents later, ask progressively—start with the most important questions. Conclude when the riglet's scope is clear and you have concrete examples.

## Planning the Reusable Documentation Contents

Transform concrete examples into effective documentation by analyzing what knowledge is needed.

For each concrete example/workflow:

1. **What knowledge is needed to execute it?** (procedures, patterns, concepts)
2. **What details are essential vs. advanced?** (core flow vs. edge cases)
3. **What reference materials would help?** (checklists, templates, troubleshooting)

Example: For a JJ riglet handling "reorganizing commits":
1. Agents need to understand: revsets, rebasing, interactive rebase workflows
2. Essential: Basic rebase commands; Advanced: complex revset patterns
3. Reference materials: Revset syntax guide, troubleshooting merge conflicts

Example: For a PDF riglet handling "extracting tables from PDFs":
1. Agents need: Understanding of PDF structure, table detection, format conversion
2. Essential: Simple table extraction; Advanced: handling complex nested tables
3. Reference materials: Format specifications, edge cases, tool limitations

Example: For a Typst riglet handling "generating documents":
1. Agents need: Typst syntax, layout patterns, styling fundamentals
2. Essential: Basic template structure; Advanced: custom layouts and functions
3. Tools needed: `typst` compiler, `pandoc` for format conversion
4. Configuration: Templates for common document types
5. Reference materials: Syntax reference, styling guide, troubleshooting layout issues

From this analysis, create a list of:
- Main sections for SKILL.md (primary workflows)
- Reference files needed (advanced patterns, troubleshooting, checklists)
- **Tools to include** (what agents will need to execute workflows)
- **Configuration** (templates, pre-configured settings)

## Writing Effective SKILL.md

SKILL.md is the core knowledge. Write for agent efficiency:

### Content Organization

Start with **overview**:
```markdown
# My Riglet

This riglet teaches [what it covers].

Primary use cases:
- Use case 1
- Use case 2
- Use case 3

See references/advanced.md for deeper patterns.
```

For documentation patterns, see [patterns.md](references/patterns.md).

### Documentation Patterns

For proven patterns to organize riglet documentation, see [patterns.md](references/patterns.md). It covers:
- Sequential workflows
- Domain-specific organization  
- Conditional details with progressive disclosure
- Troubleshooting-driven structures
- Converting Skills to riglets

### Writing Guidelines

**Avoid deeply nested references** - Keep reference links one level deep. All reference files should link directly from SKILL.md, not from other references.

**Use imperative/infinitive form**:
- Good: "Use jj to manage changes"
- Avoid: "This riglet manages changes" or "JJ is a version control system"

**Include concrete examples**:
```markdown
Bad: You can create commits with jj.

Good: To create a new commit:
  jj new -m "Add feature X"
```

**Show expected output** when relevant:
```markdown
$ jj log
@  ckd6n8pf 2025-12-15 alice (empty) Add feature X
○  xzrxt9al 2025-12-15 alice Add docs
```

**Link to references when context is available**:
```markdown
For complex scenarios, see [patterns.md](references/patterns.md) or [metadata-guide.md](references/metadata-guide.md).
```

Don't link proactively—mention references only when the agent is in a situation where they'd be relevant.

**Avoid overwhelming context** - Keep SKILL.md to ~100 lines. Extended explanations belong in reference files.

**Use relative paths for references** - All paths are relative to the file mentioning them: `[patterns.md](references/patterns.md)`

## What Goes Where: SKILL.md vs References

**Keep in SKILL.md:**
- Primary workflows and procedures agents will use most
- Common decision trees ("If X, then do Y")
- Essential concepts agents need to understand the workflows
- Links to reference files (but not the detailed content itself)

**Move to references:**
- Advanced patterns and edge cases
- Detailed specifications and schemas
- Troubleshooting guides
- Code examples longer than 10 lines
- Domain knowledge only needed for specific scenarios
- Detailed API or command documentation

**Rule of thumb:** Information should live in SKILL.md OR references, not both. Information repetition wastes token budget.

When you find yourself writing "For more details, see..." you've found something that belongs in a reference file.

## Organizing Reference Files

Reference files provide depth without bloating SKILL.md.

### Design Principle: One Level Deep

Keep all references one level deep from SKILL.md. References should not link to other references.

Good:
```
SKILL.md → references/advanced.md
SKILL.md → references/troubleshooting.md
```

Avoid:
```
SKILL.md → references/patterns.md → references/patterns-detailed.md
```

Why? Agents need to understand the full scope of what's available. If references link to other references, the structure becomes opaque and agents might miss information.

### Structure Longer References

For reference files longer than ~100 lines, include a table of contents so agents can see the full scope when previewing:

```markdown
# Advanced JJ Patterns

## Table of Contents

- Revset Syntax (line 10)
- Interactive Rebase (line 45)
- Conflict Resolution (line 80)
- Undoing Changes (line 120)

## Revset Syntax

...
```

This lets agents understand the file's full scope without reading all of it, helping them decide if they need to load it.

### Naming conventions

Use clear, specific names:
- `advanced.md` - Advanced patterns in the main topic
- `troubleshooting.md` - Common problems and solutions
- `checklists.md` - Reusable checklists
- `domain-name.md` - Domain-specific knowledge (for multi-domain riglets)
- `syntax-reference.md` - Detailed syntax specifications

## The Riglet Creation Process

Putting it all together:

1. **Understand** with concrete examples (5-10 min)
   - What workflows? What problems? What would agents ask for?

2. **Plan** the documentation structure (5-10 min)
   - Which sections for SKILL.md?
   - Which topics need reference files?
   - Any assets or templates?
   - **Does this riglet depend on other riglets?** (See below)

### Declaring Riglet Dependencies

Riglets can depend on other riglets using Nix module `imports`. This ensures that when a riglet is included in a rig, its dependencies are automatically included as well:

**Local riglets (same project):**
```nix
{ riglib, ... }:
{
  imports = [ ../agent-rig ];  # Path to another riglet in this project
  
  config.riglets.riglet-creator = {
    # ...
  };
}
```

**External riglets (from flake inputs):**
```nix
{ riglib, inputs, ... }:
{
  imports = [ inputs.my-external-riglets.riglets.some-riglet ];
  
  config.riglets.my-riglet = {
    # ...
  };
}
```

**Why use imports?**
- Ensures the dependency is automatically included when your riglet is used
- Documents the relationship explicitly in code
- Prevents errors if someone uses your riglet in a different project
- The Nix module system handles deduplication (dependencies only appear once)

**Example:** riglet-creator imports agent-rig because its documentation references agent-rig's concepts and schema.

3. **Write SKILL.md** with primary workflows (20-30 min)
   - Overview
   - 3-5 core workflows with concrete examples
   - Links to reference files

4. **Write reference files** for advanced topics (10-20 min per reference)
   - Advanced patterns
   - Troubleshooting
   - Detailed specifications

5. **Test with real tasks** (10+ min)
   - Use the riglet for actual work
   - Notice gaps or confusion
   - Update SKILL.md or references

6. **Iterate** based on usage
   - Clarify confusing sections
   - Add missing workflows
   - Reorganize if structure isn't working

## Quality Checklist

Before considering documentation complete:

- [ ] **SKILL.md exists** and covers primary workflows
- [ ] **Concrete examples** throughout (commands, output, use cases)
- [ ] **No jargon without explanation** - define domain terms
- [ ] **Links to references** mentioned naturally (not exhaustively)
- [ ] **Reference files** structured with TOC if >100 lines
- [ ] **Relative paths** all correct (tested from the docs directory)
- [ ] **No unreferenced tools** - everything mentioned has a link or exists in the rig
- [ ] **Tested in practice** - actually used for real workflows
