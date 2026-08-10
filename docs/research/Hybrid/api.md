# Hybrid API Reference

## Complete API Documentation

Full Hybrid API reference is available at:

**[docs/docs/api/hybrid.md](../../docs/api/hybrid.md)**

This document contains:
- HybridBigInt operations
- Packed/Unpacked storage modes
- Arithmetic operations on ternary data
- Performance characteristics

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

## FFI Bindings

Rust FFI bindings are available at:

**[crates/trios-hybrid/README.md](../../../../../crates/trios-hybrid/README.md)**

These provide C-compatible interfaces for hybrid arithmetic operations.

## Research Reports

Implementation details and performance analysis:

- [v2.0 Report: ./v2.0-report.md](./v2.0-report.md)
- [v2.1 Report: ./v2.1-report.md](./v2.1-report.md)

## Related

- [Ternary: ../Ternary/](../Ternary/)
- [VSA: ../VSA/](../VSA/)
