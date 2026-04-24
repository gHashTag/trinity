# Ternary Computing

## Overview

Balanced ternary computing uses values {-1, 0, +1} (trits) instead of {0, 1} (bits). This enables 50% information density improvement over binary systems.

## Key Concepts

| Concept | Description |
|----------|-------------|
| Trit | Single ternary digit: {-1, 0, +1} |
| Trit9 | 9 trits packed into 18 bits |
| Trit27 | 27 trits packed into 54 bits |
| Trit243 | 243 trits packed into 486 bits |

## Complete Documentation

Ternary computing is comprehensively documented in the main documentation site:

### Complete Guide
- **[Balanced Ternary Guide: docs/docs/concepts/balanced-ternary.md](../../docs/concepts/balanced-ternary.md)**
  - Ternary arithmetic operations
  - Conversion between ternary and binary
  - Memory efficiency analysis
  - Packed trit representation (2 bits per trit)
  - Applications in Trinity (VSA, BitNet, VM)

### Architecture Decision Record
- **[Ternary Representation ADR: docs/docs/adr/002-ternary-representation.md](../../docs/adr/002-ternary-representation.md)**
  - Packed trit encoding scheme
  - Trade-offs and implementation decisions
  - 2-bit encoding: {-1=00, 0=01, +1=10}

## Architecture Benefits

- **50% density:** Each trit carries ~1.58 bits (vs 1 bit in binary)
- **Natural alignment:** Powers of 3 (3, 9, 27, 81, 243, 729)
- **Golden ratio:** All dimensions follow 3^k scaling
- **FPGA-friendly:** Efficient hardware implementation

## Related

- **[VSA: ../VSA/](../VSA/)** - Vector Symbolic Architecture uses trits
- **[Hybrid: ../Hybrid/](../Hybrid/)** - Hybrid BigInt operations
