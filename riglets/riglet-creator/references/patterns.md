# Riglet Documentation Patterns

Proven patterns for organizing riglet documentation effectively.

## Pattern 1: Sequential Workflow

Use when the riglet teaches step-by-step procedures:

```markdown
## Workflow: Rotating PDFs

1. Load document: `pdftool load file.pdf`
2. Rotate pages: `pdftool rotate -a 90 file.pdf`
3. Save result: `pdftool save file.pdf`

For bulk operations: See [batch-operations.md](references/batch-operations.md)
```

## Pattern 2: Domain-Specific Organization

Use when covering multiple domains (e.g., BigQuery finance vs. product metrics):

```markdown
# BigQuery Riglet

## Overview

Query BigQuery for metrics across different domains.

## Financial Metrics

See [finance.md](references/finance.md) for:
- Revenue calculations
- Billing costs

## Product Metrics

See [product.md](references/product.md) for:
- Feature usage
- API adoption
```

Agents only load the domain reference they need.

## Pattern 3: Conditional Details with Progressive Disclosure

Use for tools/topics with basic and advanced usage:

```markdown
## Creating Documents

Basic template for most cases:

```nix
typst { title = "..."; }
```

**Advanced layouts**: See [layouts.md](references/layouts.md)
**Custom styling**: See [styling.md](references/styling.md)
**Performance**: See [performance.md](references/performance.md)
```

## Pattern 4: Troubleshooting-Driven Organization

Use when users commonly hit problems:

```markdown
## Common Workflows

- Creating a change (simple case)
- Rebasing changes

## Troubleshooting

See [troubleshooting.md](references/troubleshooting.md) for:
- "I accidentally deleted a change"
- "Rebasing is creating conflicts"
- "I need to undo multiple changes"
```

## Pattern 5: Skill-to-Riglet Direct Port

When converting an existing Agent Skill to a riglet:

1. Copy SKILL.md content verbatim (it's already well-written)
2. Move advanced sections to `references/` subdirectory
3. Update any skill-specific instructions (build scripts, etc.)
4. Keep the same organization and linking structure

This is the lowest-friction conversion.

