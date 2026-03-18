# tri cell — Quick Reference

> 1-page cheat sheet for Trinity Honeycomb Module Management

## Essential Commands (Top 10)

```bash
tri cell list                    # List all cells with status
tri cell info <id>               # Show cell details (tags, deps, health)
tri cell init <name>             # Create new cell from template
tri cell check --sync            # Validate all + rebuild registry
tri cell health                  # Per-cell health score breakdown
tri cell deps <id> --tree        # Recursive dependency tree
tri cell fix --all               # Auto-fix perms, deps, ids, scope, counts
tri cell graph                   # Output Mermaid dependency diagram
tri cell watch                   # Live health dashboard (5s refresh)
tri cell doctor                  # Full heal cycle
```

## Quick Workflows

### Add a new cell
```bash
tri cell init trinity.mymodule --template library
# Edit src/mymodule/cell.tri
tri cell check --sync
```

### Wrap existing code
```bash
tri cell create-all --dry-run    # Preview
tri cell create-all              # Create cell.tri for all
```

### Fix broken cell
```bash
tri cell fix --all --dry-run     # Preview changes
tri cell fix --all               # Apply fixes
tri cell check --sync            # Sync registry
```

### Monitor health
```bash
tri cell health                  # One-time check
tri cell health --json > h.json  # Export
tri cell watch                   # Live dashboard
```

### Auto-detect dependencies
```bash
tri cell deps --auto-detect      # Scan @imports
tri cell deps --auto-detect --write  # Update cell.tri
```

### Find orphans
```bash
tri cell orphans                 # Zig files not in any cell
tri cell map                     # Binaries without mapping
```

## Common Flags

| Flag | Description |
|------|-------------|
| `--json` | Output as JSON |
| `--help` | Show help text |
| `--verbose` | Detailed output |
| `--dry-run` | Preview without writing |
| `--sync` | Rebuild registry after action |
| `--template <name>` | Use template (agent/tool/library/virtual) |
| `--with-test` | Create test file with cell |
| `--tree` | Recursive dependency tree |
| `--auto-register` | Detect and register new cells |
| `--yes` | Skip confirmation prompts |

## Templates

| Template | Use For |
|----------|---------|
| `agent` | Autonomous agent with tools, context, isolation |
| `tool` | CLI utility with commands and exports |
| `library` | Reusable library with exports and tests |
| `virtual` | Virtual sub-cell for modular organization |

## Health Grades

| Score | Grade | Meaning |
|-------|-------|---------|
| 90-100 | A | HEALTHY |
| 70-89 | B | RECOVERING |
| 50-69 | C | INFECTED |
| 0-49 | F | CRITICAL |

Formula: `100 * (0.4*gen + 0.3*comp + 0.2*spec + 0.1*test)`

## Permission Levels

| Level | FS | Net | Process | FFI | Use Case |
|-------|----|-----|---------|-----|----------|
| L0 | read | none | none | none | Pure functions |
| L1 | read | none | none | none | Utilities |
| L2 | read | local | none | none | Local services |
| L3 | write | local | spawn | none | Tools |
| L4 | write | external | spawn | native | Agents |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Cell not found | Run `tri cell check --sync` |
| Health < 70 | Run `tri cell fix --all` |
| Orphan files | Run `tri cell create-all` |
| Dependency cycle | Run `tri cell deps --cycles` |
| Lint errors | Run `tri cell lint` then `tri cell fix --perms` |
| Registry outdated | Run `tri cell check --sync` |
| Missing deps | Run `tri cell deps --auto-detect --write` |
| Broken imports | Run `tri cell check-boundaries` |

## Key Files

| Path | Purpose |
|------|---------|
| `cell.tri` | Cell manifest (in each module dir) |
| `.trinity/cells/registry.json` | Auto-generated registry |
| `~/.tri/templates/` | Custom cell templates |
| `src/tri/cytoplasm.zig` | Cell management impl |

## See Also

- Full docs: `docs/tri-cell.md`
- Templates: `src/tri/templates/README.md`
- Parser: `src/tri/ribosome.zig`
