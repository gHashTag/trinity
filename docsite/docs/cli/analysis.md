---
sidebar_position: 4
sidebar_label: Code Analysis
---

# Code Analysis

Static analysis, full-text search, and dependency graph tools.

## analyze

Static code analysis with pattern detection.

```bash
tri analyze [file or directory]
tri analyze src/
tri analyze src/vsa.zig
```

Reports: TODO/FIXME count, large file detection (>500 lines), function visibility (public vs private ratio), patterns found.

**Example output:**

```
TRI ANALYZE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Target: src/

  Code Metrics:
    Zig files scanned:  210+
    TODOs found:        12
    FIXMEs found:       3
    Large files (>500): 8

  Function Visibility:
    Public:    347
    Private:   189
    Ratio:     64.7% public

  Patterns:
    test blocks:   94
    error unions:  67
    comptime:      23
```

## search

Full-text code search across the codebase.

```bash
tri search <pattern> [path]
tri search "cosineSimilarity"
tri search "TODO" src/vsa.zig
```

Searches all `.zig` files and displays matching lines with file path and line number.

**Example output:**

```
TRI SEARCH: "cosineSimilarity"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  src/vsa.zig:142: pub fn cosineSimilarity(a: []const Trit, b: []const Trit) f64 {
  src/sdk.zig:89:     const sim = vsa.cosineSimilarity(self.data, other.data);
  src/tri/tri_math.zig:301:     // Uses cosineSimilarity for vector comparison

  Found: 3 matches in 3 files
```

## deps

Dependency graph analysis.

```bash
tri deps [module]
tri deps src/vsa.zig
```

Shows import chains and reverse dependency tree.

**Example output:**

```
DEPENDENCY ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Module: src/vsa.zig

  Imports:
    └── std (stdlib)

  Imported by:
    ├── src/sdk.zig
    ├── src/hybrid.zig
    ├── src/vm.zig
    └── src/tri/tri_math.zig

  Depth: 1 (leaf module)
```
