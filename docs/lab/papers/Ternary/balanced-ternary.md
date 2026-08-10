# Balanced Ternary - Complete Guide

## Overview

Balanced ternary computing uses values {-1, 0, +1} (trits) instead of {0, 1} (bits). This enables 50% information density improvement over binary systems.

## Full Documentation

Complete balanced ternary documentation is available at:

**[docs/docs/concepts/balanced-ternary.md](../../docs/concepts/balanced-ternary.md)**

This document contains:
- Ternary arithmetic operations
- Conversion between ternary and binary
- Memory efficiency analysis
- Packed trit representation (2 bits per trit)

## Key Concepts

| Concept | Description |
|----------|-------------|
| Trit | Single ternary digit: {-1, 0, +1} |
| Trit9 | 9 trits packed into 18 bits |
| Trit27 | 27 trits packed into 54 bits |
| Trit243 | 243 trits packed into 486 bits |

## Architecture Benefits

- **50% density:** Each trit carries ~1.58 bits (vs 1 bit in binary)
- **Natural alignment:** Powers of 3 (3, 9, 27, 81, 243, 729)
- **Golden ratio:** All dimensions follow 3^k scaling

## Related

- [ADR for representation: docs/docs/adr/002-ternary-representation.md](../../docs/adr/002-ternary-representation.md)
- [Hybrid operations: ../Hybrid/api.md](../Hybrid/api.md)
