---
sidebar_position: 4
sidebar_label: Code Analysis
---

# Code Analysis

Static analysis, full-text search, and dependency graph tools.

> **Note:** These commands are currently placeholders. They display system information (same as `tri info`) instead of performing analysis. Full implementations are planned for future cycles.

## analyze

Static code analysis with pattern detection.

```bash
tri analyze [file or directory]
tri analyze src/
tri analyze src/vsa.zig
```

**Current status:** Displays system info. Planned to report: TODO/FIXME count, large file detection (\>500 lines), function visibility (public vs private ratio), pattern detection.

## search

Full-text code search across the codebase.

```bash
tri search <pattern> [path]
tri search "cosineSimilarity"
tri search "TODO" src/vsa.zig
```

**Current status:** Displays system info. Planned to search all `.zig` files and display matching lines with file path and line number.

## deps

Dependency graph analysis.

```bash
tri deps [module]
tri deps src/vsa.zig
```

**Current status:** Displays system info. Planned to show import chains and reverse dependency trees.
