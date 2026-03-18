# Trinity Naming Convention Standard

**Version:** 1.0
**Status:** Active
**Scope:** All Zig source files in Trinity project

## Overview

This document defines the naming standard for Trinity codebase. Consistent naming reduces cognitive load, improves navigation, and makes the codebase easier to understand for new contributors.

## File Naming

### Hot-Path Core Files

Core library files (in `src/vsa/`, `src/common/`, etc.):

| Pattern | Description | Examples |
|---------|-------------|----------|
| `{domain}.zig` | Single module for domain | `core.zig`, `encoding.zig`, `storage.zig` |
| `{domain}_{sub}.zig` | Sub-domain within domain | `agent/system.zig`, `agent/memory.zig` |

**Good:**
- `vsa/core.zig` - Core VSA operations
- `common/protocol.zig` - Protocol definitions
- `vsa/encoding.zig` - Text encoding operations

**Avoid:**
- `stuff.zig` - Too generic
- `utils.zig` - Non-specific
- `temp.zig` - Indicates incomplete work

### Test Files

| Pattern | Description | Examples |
|---------|-------------|----------|
| `{module}_test.zig` | Unit tests for module | `vsa/core_test.zig` |
| `{domain}_tests.zig` | Test suite for domain | `vsa/tests.zig` |

### FPGA/Domain-Specific Files

| Pattern | Description | Examples |
|---------|-------------|----------|
| `{fpga}_{op}.zig` | FPGA-specific operation | `fpga_bind.zig` |
| `{target}_{device}.zig` | Target-specific driver | `uart_host_v6.zig` |

## Module Naming (in Zig code)

### Imports

```zig
// Standard library
const std = @import("std");

// Local project - use relative paths for same domain
const protocol = @import("uart_protocol.zig");
const vectors = @import("uart_vectors.zig");

// Cross-domain - use absolute from src/
const vsa = @import("vsa");
const common = @import("common");
```

### Type Names

| Pattern | Description | Examples |
|---------|-------------|----------|
| `PascalCase` | All types (structs, enums, unions) | `Vector16`, `Trit`, `Command` |
| `{Name}Error` | Error sets | `VsaError`, `ParseError` |

### Function Names

| Pattern | Description | Examples |
|---------|-------------|----------|
| `camelCase` | All functions | `bindVectors`, `randomVector` |
| `get{Noun}` | Getter | `getValue`, `getConfig` |
| `set{Noun}` | Setter | `setValue`, `setMode` |
| `is{Adjective}` | Boolean check | `isEmpty`, `isValid` |
| `{verb}N` | Create/build | `init`, `alloc`, `format` |

### Constants

```zig
// Public constants: UPPER_SNAKE_CASE
pub const MAX_VECTOR_SIZE: usize = 16;
pub const DEFAULT_TIMEOUT_MS: u32 = 5000;

// Private constants: same pattern or lower_case
const private_constant: u8 = 42;
```

## Directory Structure

```
src/
├── common/           # Shared utilities, protocols
│   ├── protocol.zig  # Protocol definitions
│   ├── constants.zig # Sacred constants (PHI, GAMMA, etc.)
│   └── errors.zig    # Common error types
├── vsa/              # Vector Symbolic Architecture
│   ├── core.zig      # Core VSA operations
│   ├── encoding.zig  # Text encoding
│   └── storage.zig   # Storage backends
├── tri/              # TRI CLI
│   └── tri_vsa.zig   # VSA commands
└── vibeec/           # VIBEE compiler tools
```

## Re-exports

When re-exporting from submodules:

```zig
// src/vsa.zig - Main VSA entry point
pub const core = @import("vsa/core.zig");
pub const encoding = @import("vsa/encoding.zig");

// Re-export commonly used items
pub const Vector16 = core.Vector16;
pub const bind = core.bind;
pub const bundle = core.bundle;
```

## Version-Suffixed Files

For versions that need coexistence:

```zig
uart_host_v5.zig  // UART host v5.0 (2-byte length)
uart_host_v6.zig  // UART host v6.0 (1-byte length, improved CRC)
```

## Forbidden Patterns

1. **Hungarian notation** - `iCount`, `pszString`
2. **Abbreviations** (except well-known ones):
   - Use `vector` not `vec`
   - Use `operation` not `op`
   - OK: `id`, `url`, `http`, `config`
3. **Numeric prefixes without purpose** - `10k_vsa.zig` → use `vsa_bench_10k.zig`

## Sacred Constants (src/common/constants.zig)

These have defined names and MUST NOT be renamed:

```zig
pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const GAMMA: f64 = 0.23606797749978969641;
pub const TRINITY: f64 = 3.0;
```

## Compliance Checklist

- [ ] Files use snake_case: `my_module.zig`
- [ ] Types use PascalCase: `MyStruct`
- [ ] Functions use camelCase: `myFunction`
- [ ] Constants use UPPER_SNAKE_CASE: `MY_CONSTANT`
- [ ] No generic names: `stuff.zig`, `utils.zig`, `temp.zig`
- [ ] Imports use consistent relative/absolute patterns
- [ ] Sacred constants imported from `common/constants.zig`

## Migration Path

When renaming existing files:

1. Create new file with correct name
2. Update imports in dependent files
3. Update build.zig if needed
4. Delete old file
5. Run tests to verify

```bash
# Example migration
git mv src/old_name.zig src/new_name.zig
# Update imports
zig fmt src/
# Verify build
zig build test
```

---

**φ² + 1/φ² = 3 = TRINITY**
