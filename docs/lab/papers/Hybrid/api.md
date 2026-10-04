# Hybrid API Reference

## Complete API Documentation

Full Hybrid API reference is available at:

**[docs/docs/api/hybrid.md](../../../docs/api/hybrid.md)**

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

Historical Rust FFI bindings are not present in this checkout. Former path:

**crates/trios-hybrid/README.md (historical path `../../../../../crates/trios-hybrid/README.md`; not present in this checkout)**

These historical bindings described C-compatible interfaces; their implementation is not verified by this checkout.

## Research Reports

Implementation details and performance analysis:

- [v2.0 Report: ./v2.0-report.md](../../../research/models/Hybrid/v2.0-report.md)
- [v2.1 Report: ./v2.1-report.md](../../../research/models/Hybrid/v2.1-report.md)

## Related

- [Ternary: ../Ternary/](../Ternary/)
- [VSA: ../VSA/](../VSA/)
