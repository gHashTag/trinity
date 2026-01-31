---
sidebar_position: 2
---

# VM API Reference

Virtual Machine for VSA programs.

## VSAVM

### Creating a VM

```zig
var vm = trinity.VSAVM.init(allocator);
defer vm.deinit();
```

### Loading a Program

```zig
const program = [_]trinity.VSAInstruction{
    .{ .opcode = .v_random, .dst = 0, .imm = 111 },
    .{ .opcode = .v_bind, .dst = 2, .src1 = 0, .src2 = 1 },
    .{ .opcode = .halt },
};

try vm.loadProgram(&program);
```

### Running

```zig
try vm.run();  // Run until halt

// Or step-by-step
while (try vm.step()) {}
```

### Accessing Results

```zig
// Scalar results
const s0 = vm.registers.s0;  // i64
const f0 = vm.registers.f0;  // f64

// Vector registers
const v0 = vm.registers.v0;  // HybridBigInt
```

---

## VSAInstruction

```zig
const VSAInstruction = struct {
    opcode: VSAOpcode,
    dst: u8 = 0,    // Destination register (0-3)
    src1: u8 = 0,   // Source register 1
    src2: u8 = 0,   // Source register 2
    imm: i64 = 0,   // Immediate value
};
```

---

## Opcodes

### Vector Load/Store

| Opcode | Description | Example |
|--------|-------------|---------|
| `v_load` | Load from memory | `v_load dst, imm` |
| `v_store` | Store to memory | `v_store src1` |
| `v_const` | Load constant | `v_const dst, imm` |
| `v_random` | Generate random | `v_random dst, seed` |

### VSA Operations

| Opcode | Description | Example |
|--------|-------------|---------|
| `v_bind` | Bind vectors | `v_bind dst, src1, src2` |
| `v_unbind` | Unbind vectors | `v_unbind dst, src1, src2` |
| `v_bundle2` | Bundle 2 | `v_bundle2 dst, src1, src2` |
| `v_bundle3` | Bundle 3 | `v_bundle3 dst, src1, src2` |

### Similarity

| Opcode | Description | Result |
|--------|-------------|--------|
| `v_dot` | Dot product | `s0 = dot(src1, src2)` |
| `v_cosine` | Cosine similarity | `f0 = cosine(src1, src2)` |
| `v_hamming` | Hamming distance | `s0 = hamming(src1, src2)` |

### Arithmetic

| Opcode | Description |
|--------|-------------|
| `v_add` | Vector addition |
| `v_neg` | Vector negation |
| `v_mul` | Element-wise multiply |

### Permute

| Opcode | Description |
|--------|-------------|
| `v_permute` | Cyclic shift right |
| `v_ipermute` | Cyclic shift left |
| `v_seq` | Encode sequence |

### Memory Management

| Opcode | Description |
|--------|-------------|
| `v_pack` | Pack vector (save memory) |
| `v_unpack` | Unpack vector |
| `v_mov` | Copy register |

### Control

| Opcode | Description |
|--------|-------------|
| `v_cmp` | Compare vectors |
| `nop` | No operation |
| `halt` | Stop execution |

---

## Registers

### Vector Registers

- `v0`, `v1`, `v2`, `v3`: HybridBigInt vectors

### Scalar Registers

- `s0`, `s1`: i64 (for dot product, hamming)
- `f0`, `f1`: f64 (for similarity)

### Condition Codes

- `cc_zero`: Similarity near zero
- `cc_neg`: Negative similarity
- `cc_pos`: Positive similarity

---

## Example Program

```zig
const program = [_]trinity.VSAInstruction{
    // Create vectors
    .{ .opcode = .v_random, .dst = 0, .imm = 111 },
    .{ .opcode = .v_random, .dst = 1, .imm = 222 },
    
    // Bind them
    .{ .opcode = .v_bind, .dst = 2, .src1 = 0, .src2 = 1 },
    
    // Unbind
    .{ .opcode = .v_unbind, .dst = 3, .src1 = 2, .src2 = 1 },
    
    // Check similarity (should be ~1.0)
    .{ .opcode = .v_cosine, .src1 = 0, .src2 = 3 },
    
    .{ .opcode = .halt },
};
```
