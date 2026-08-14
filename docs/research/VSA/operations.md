# VSA Operations - Quick Reference

## Core Operations

### 1. Bind (Binding)
Combines two VSA vectors into one using similarity search.

### 2. Unbind (Unbinding)
Extracts specific patterns from a bound VSA using a key.

### 3. Bundle (Bundling)
Combines multiple VSA vectors with associated metadata.

## Operations Table

| Operation | API Function | Parameters |
|-----------|--------------|------------|
| Bind | `vsa.bind(a, b)` | Two VSA vectors |
| Unbind | `vsa.unbind(bound, key)` | Bound VSA, key pattern |
| Bundle | `vsa.bundle(vsas, meta)` | VSA array, metadata |
| Similarity | `vsa.similarity(a, b)` | Two VSA vectors |
| Intersection | `vsa.intersect(a, b)` | Two VSA vectors |
| Union | `vsa.union(a, b)` | Two VSA vectors |

## Mathematical Properties

- **Associative:** Bind/Unbind operations preserve semantic meaning
- **Distributed:** Similarity operates across all dimensions
- **Commutative:** Operations order-independent for some cases

## Full Documentation

- [Complete API: docs/docs/api/vsa.md](../../docs/api/vsa.md)
- [15-minute Tutorial: docs/docs/tutorials/vsa-operations.md](../../docs/tutorials/vsa-operations.md)
- [Quick Reference: docs/docs/cheatsheets/vsa-operations.md](../../docs/cheatsheets/vsa-operations.md)

## Implementation

- **Zig:** Core VSA operations in Trinity library
- **Rust FFI:** `crates/trios-vsa/` bindings
- **FPGA:** Zero-DSP implementation in Sacred ALU

See [overview.md](./overview.md) for architecture details.
