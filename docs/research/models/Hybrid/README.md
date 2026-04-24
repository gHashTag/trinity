# Hybrid BigInt

## Overview

HybridBigInt provides arbitrary precision balanced ternary arithmetic with flexible storage modes for optimal performance and memory efficiency.

## Key Concepts

### HybridBigInt
Arbitrary precision balanced ternary arithmetic supporting:
- **Packed mode:** 2 bits per trit for storage efficiency
- **Unpacked mode:** 4 bits per trit for computation efficiency

### Storage Modes

| Mode | Bits per Trit | Use Case |
|-------|---------------|------------|
| Packed | 2 | Memory storage, disk I/O |
| Unpacked | 4 | Active computation, intermediate values |

## Complete Documentation

Hybrid BigInt is comprehensively documented in the main documentation site:

### API Reference
- **[API Reference: docs/docs/api/hybrid.md](../../docs/api/hybrid.md)**
  - Complete HybridBigInt operations
  - Packed/Unpacked storage modes
  - Arithmetic operations on ternary data
  - Performance characteristics (1.58 bits/trit memory efficiency)
  - Live interactive demo

### Implementation
- **[FFI Bindings: crates/trios-hybrid/README.md](../../../../../crates/trios-hybrid/README.md)** - Rust FFI interface
  - C-compatible interfaces for hybrid arithmetic operations

## Research Reports

Implementation details and performance analysis are available in the research archive:
- v2.0, v2.1, v2.35, v2.42 reports with iterative improvements
- Real-world hybrid applications
- Golden chain implementations with Hybrid

Search for "hybrid" in [`docs/docs/research/`](../../research/) for detailed reports.

## Related

- **[Ternary: ../Ternary/](../Ternary/)** - Ternary computing fundamentals
- **[VSA: ../VSA/](../VSA/)** - Vector Symbolic Architecture
