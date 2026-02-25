---
sidebar_position: 3
---

# VM API

Ternary Virtual Machine for Hyperdimensional Computing.

**Module:** `src/vm.zig`

## Registers

| Register | Type | Description |
|----------|------|-------------|
| `v0-v3` | HybridBigInt | Vector registers |
| `s0-s1` | i64 | Scalar results |
| `f0-f1` | f64 | Float results |
| `pc` | u32 | Program counter |

## Opcodes

### Vector Operations

| Opcode | Description |
|--------|-------------|
| `v_load` | Load vector from memory |
| `v_store` | Store vector to memory |
| `v_random` | Generate random vector |

### VSA Operations

| Opcode | Description |
|--------|-------------|
| `v_bind` | Bind two vectors |
| `v_bundle2` | Bundle 2 vectors |
| `v_bundle3` | Bundle 3 vectors |

### Similarity

| Opcode | Description |
|--------|-------------|
| `v_dot` | Dot product → s0 |
| `v_cosine` | Cosine similarity → f0 |
| `v_hamming` | Hamming distance → s0 |

## Usage

```zig
var machine = try vm.VSAVM.init(allocator);
defer machine.deinit();

try machine.loadProgram(&program);
try machine.run();
```
