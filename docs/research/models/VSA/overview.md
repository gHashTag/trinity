# VSA (Vector Symbolic Architecture) Overview

## What is VSA

Vector Symbolic Architecture (VSA) is the core foundation of Trinity's neural system. It enables efficient symbolic operations on ternary representations.

## Key Concepts

- **Trits:** {-1, 0, +1} - basic unit of ternary computation
- **Binding:** Combines two VSA vectors into one (similarity search)
- **Unbinding:** Extracts specific patterns from bound VSA
- **Bundling:** Combine multiple VSAs with metadata

## Operations

| Operation | Description |
|-----------|-------------|
| Bind | Combine two VSAs via similarity |
| Unbind | Extract pattern with key |
| Bundle | Group VSAs with metadata |
| Similarity | Compare VSAs for semantic proximity |

## Documentation

- [API Reference: docs/docs/api/vsa.md](../../docs/api/vsa.md)
- [Tutorial: docs/docs/tutorials/vsa-operations.md](../../docs/tutorials/vsa-operations.md)
- [Cheat Sheet: docs/docs/cheatsheets/vsa-operations.md](../../docs/cheatsheets/vsa-operations.md)
- [FFI Bindings: crates/trios-vsa/README.md](../../../../../crates/trios-vsa/README.md)
- [Examples: .trinity/ralph/examples/vsa_usage.zig](../../../../../.trinity/ralph/examples/vsa_usage.zig)

## FPGA Implementation

VSA operations are implemented in FPGA for zero-DSP inference:
- XC7A100T target
- Yosys open toolchain
- See [TRINITY_S3AI_UNIFIED_FRAMEWORK.md](../../research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md) for details

## Performance

- **Throughput:** 35 tok/s @ 0.5W (from Sacred ALU)
- **Energy:** Efficient due to zero DSP blocks
- **Precision:** Full-precision with ternary representation

## Related

VSA is integrated with:
- [Ternary Models: ../Ternary/](../Ternary/)
- [Hybrid Models: ../Hybrid/](../Hybrid/)
