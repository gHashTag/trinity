# Vector Symbolic Architecture (VSA)

## Overview

Vector Symbolic Architecture (VSA) is the core foundation of Trinity's neural system. It enables efficient symbolic operations on ternary representations using trits {-1, 0, +1}.

## Key Concepts

- **Trits:** {-1, 0, +1} - basic unit of ternary computation
- **Binding:** Combines two VSA vectors into one (similarity search)
- **Unbinding:** Extracts specific patterns from bound VSA
- **Bundling:** Combine multiple VSAs with metadata
- **Similarity:** Compare VSAs for semantic proximity

## Complete Documentation

VSA is comprehensively documented in the main documentation site:

### API Reference
- **[API Reference: docs/docs/api/vsa.md](../../docs/api/vsa.md)** - Complete API with interactive demo
  - Core operations: bind, unbind, bundle2, bundle3, permute
  - Similarity operations: cosineSimilarity, hammingDistance, dotSimilarity

### Tutorials & Guides
- **[Tutorial: docs/docs/tutorials/vsa-operations.md](../../docs/tutorials/vsa-operations.md)** - 15-minute VSA operations tutorial
  - Complete code examples
  - Interactive JSX demo
  - CLI usage examples

- **[Cheat Sheet: docs/docs/cheatsheets/vsa-operations.md](../../docs/cheatsheets/vsa-operations.md)** - Quick reference
  - Operation summaries with symbols
  - Performance benchmarks
  - Common patterns

### Related Concepts
- **[Balanced Ternary: docs/docs/concepts/balanced-ternary.md](../../docs/concepts/balanced-ternary.md)** - Ternary computing fundamentals
- **[Ternary ADR: docs/docs/adr/002-ternary-representation.md](../../docs/adr/002-ternary-representation.md)** - Packed trit encoding

### Implementation
- **[FFI Bindings: crates/trios-vsa/README.md](../../../../../crates/trios-vsa/README.md)** - Rust FFI interface
- **[Examples: .trinity/ralph/examples/vsa_usage.zig](../../../../../.trinity/ralph/examples/vsa_usage.zig)** - Zig examples

## FPGA Implementation

VSA operations are implemented in FPGA for zero-DSP inference:
- XC7A100T target
- Yosys open toolchain
- See [Unified Framework](../../research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md) for details

## Performance

- **Throughput:** 35 tok/s @ 0.5W (from Sacred ALU)
- **Energy:** Efficient due to zero DSP blocks
- **Precision:** Full-precision with ternary representation
