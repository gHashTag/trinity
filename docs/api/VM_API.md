# VM API Reference

> Ternary Virtual Machine for Hyperdimensional Computing

**Module:** `src/vm.zig`

---

## Overview

The TVC VM is a stack-based virtual machine optimized for VSA operations. It uses HybridBigInt for memory-efficient vector storage.

---

## Registers

### Vector Registers

| Register | Type | Description |
|----------|------|-------------|
| `v0-v3` | HybridBigInt | General-purpose vector registers |

### Scalar Registers

| Register | Type | Description |
|----------|------|-------------|
| `s0-s1` | i64 | Integer results (dot product) |
| `f0-f1` | f64 | Float results (similarity) |
| `pc` | u32 | Program counter |

### Condition Codes

| Flag | Description |
|------|-------------|
| `cc_zero` | Last result was zero |
| `cc_neg` | Last result was negative |
| `cc_pos` | Last result was positive |

---

## Opcodes

### Vector Operations

| Opcode | Description |
|--------|-------------|
| `v_load` | Load vector from memory |
| `v_store` | Store vector to memory |
| `v_const` | Load constant vector |
| `v_random` | Generate random vector |

### VSA Operations

| Opcode | Description |
|--------|-------------|
| `v_bind` | Bind two vectors (XOR-like) |
| `v_unbind` | Unbind (same as bind) |
| `v_bundle2` | Bundle 2 vectors |
| `v_bundle3` | Bundle 3 vectors |

### Similarity Operations

| Opcode | Description |
|--------|-------------|
| `v_dot` | Dot product → s0 |
| `v_cosine` | Cosine similarity → f0 |
| `v_hamming` | Hamming distance → s0 |

### Arithmetic

| Opcode | Description |
|--------|-------------|
| `v_add` | Vector addition |
| `v_neg` | Vector negation |
| `v_mul` | Element-wise multiplication |

### Memory Management

| Opcode | Description |
|--------|-------------|
| `v_pack` | Pack vector (save memory) |
| `v_unpack` | Unpack vector (for computation) |

### Permutation

| Opcode | Description |
|--------|-------------|
| `v_permute` | Cyclic right shift |
| `v_ipermute` | Cyclic left shift |
| `v_seq` | Encode sequence |

### Control

| Opcode | Description |
|--------|-------------|
| `v_mov` | Move between registers |
| `v_cmp` | Compare vectors |
| `nop` | No operation |
| `halt` | Stop execution |

---

## Instruction Format

```zig
pub const VSAInstruction = struct {
    opcode: VSAOpcode,
    dst: u4,      // Destination register
    src1: u4,     // Source register 1
    src2: u4,     // Source register 2
    imm: i32,     // Immediate value
};
```

---

## Usage Example

```zig
const vm = @import("vm.zig");

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    // Create VM instance
    var machine = try vm.VSAVM.init(allocator);
    defer machine.deinit();

    // Load program
    const program = [_]vm.VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .src1 = 0, .src2 = 0, .imm = 1000 },
        .{ .opcode = .v_random, .dst = 1, .src1 = 0, .src2 = 0, .imm = 1000 },
        .{ .opcode = .v_bind, .dst = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .v_cosine, .dst = 0, .src1 = 0, .src2 = 2, .imm = 0 },
        .{ .opcode = .halt, .dst = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    try machine.loadProgram(&program);
    try machine.run();

    // Result in f0
    std.debug.print("Similarity: {d}\n", .{machine.registers.f0});
}
```

---

## See Also

- [VSA_API.md](VSA_API.md) — VSA operations
- [HYBRID_API.md](HYBRID_API.md) — HybridBigInt storage
