# ЖАР ПТИЦА (FIREBIRD)

**Ternary Virtual Anti-Detect Browser**

```
φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
V = n × 3^k × π^m × φ^p × e^q
```

## Overview

Firebird is a ternary computing framework for browser fingerprint evasion. It uses Vector Symbolic Architecture (VSA) with balanced ternary vectors to create unique, human-like fingerprints that evade AI-based detection systems.

### Key Features

- **Ternary VSA**: 10,000+ dimension balanced ternary vectors (-1, 0, +1)
- **SIMD Acceleration**: 4-33x speedup on vector operations
- **B2T Integration**: Binary-to-Ternary WASM conversion pipeline
- **Evolutionary Optimization**: Parallel genetic algorithm for fingerprint evolution
- **Virtual Navigation**: Navigate code space without HTML rendering

## Installation

### Build from Source

```bash
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Build Firebird CLI
zig build

# Binary located at: ./zig-out/bin/firebird
```

### Cross-Platform Release

```bash
# Build for all platforms (Linux, macOS, Windows)
zig build release

# Binaries in: ./zig-out/release/
#   x86_64-linux/firebird
#   x86_64-macos/firebird
#   aarch64-macos/firebird
#   x86_64-windows/firebird.exe
```

## Usage

### Commands

```bash
# Show help
firebird help

# Evolve fingerprint to evade detection
firebird evolve --dim 10000 --pop 50 --gen 100

# Convert WASM to TVC IR
firebird convert --input=module.wasm --output=module.tvc

# Execute TVC IR with virtual navigation
firebird execute --ir=module.tvc --steps=20

# Run performance benchmarks
firebird benchmark --dim 100000

# Show system information
firebird info
```

### Evolve Command

Evolve a fingerprint using genetic algorithm:

```bash
firebird evolve \
  --dim 10000 \      # Vector dimension
  --pop 50 \         # Population size
  --gen 100 \        # Max generations
  --threads 4 \      # Parallel threads
  --target 0.9 \     # Target fitness
  --output fp.bin    # Save fingerprint
```

With TVC IR target (B2T integration):

```bash
firebird evolve \
  --ir module.tvc \  # Use TVC IR as evolution target
  --dim 10000 \
  --output evolved.fp
```

### Convert Command

Convert WASM binary to TVC IR:

```bash
firebird convert --input=app.wasm --output=app.tvc
```

Output:
```
WASM to TVC Conversion
═══════════════════════════════════════════════════════════════
  Input:  app.wasm
  Output: app.tvc

  Loaded: 1024 bytes in 35us
  Parsed: 5 functions, 3 types in 15us
  Converted: 5 blocks, 42 instructions in 12us
  Saved: app.tvc in 144us

═══════════════════════════════════════════════════════════════
CONVERSION COMPLETE
```

### Execute Command

Execute TVC IR with virtual navigation:

```bash
firebird execute --ir=app.tvc --dim=10000 --steps=20
```

Output:
```
TVC IR Execution with Virtual Navigation
═══════════════════════════════════════════════════════════════
  IR File:   app.tvc
  Dimension: 10000
  Steps:     20

Virtual Navigation:
───────────────────────────────────────────────────────────────
  Initial: similarity=0.0014
  Step  1: similarity=0.0400
  ...
  Step 20: similarity=0.3500
───────────────────────────────────────────────────────────────

Evasion Metrics:
───────────────────────────────────────────────────────────────
  Similarity to default: 0.0089 (target: <0.5)
  Similarity to module:  0.3500 (target: >0.7)
  Evasion status: PASS
```

## Architecture

### B2T Pipeline

```
WASM Binary → Parser → WasmModule → Lifter → TVC IR → Encoder → TritVec
                                                          ↓
                                              NavigationState
                                                          ↓
                                              Virtual Navigation
```

### TVC Opcodes

| Opcode | Description |
|--------|-------------|
| t_add | Ternary addition |
| t_sub | Ternary subtraction |
| t_mul | Ternary multiplication |
| t_and | Ternary AND |
| t_or | Ternary OR |
| t_xor | Ternary XOR |
| t_push | Push to stack |
| t_pop | Pop from stack |
| t_load | Load from memory |
| t_store | Store to memory |
| t_br | Branch |
| t_br_trit | 3-way branch |
| t_call | Function call |
| t_ret | Return |

### VSA Operations

- **Bind**: XOR-like operation for association
- **Bundle**: Majority voting for superposition
- **Permute**: Cyclic shift for sequence encoding
- **Similarity**: Cosine similarity for comparison

## Performance

### SIMD Speedups (dim=10000)

| Operation | Scalar | SIMD | Speedup |
|-----------|--------|------|---------|
| Bind | 117μs | 25μs | 4.7x |
| Dot Product | 91μs | 5.5μs | 16.5x |
| Hamming | 107μs | 4.4μs | 24.3x |

### Evolution Performance

- 3ms per generation (parallel, 4 threads)
- 314ms for 100 generations
- 1.35x speedup from parallelization

## File Formats

### TVC IR (.tvc)

Binary format:
```
[4 bytes] Magic: "TVC1"
[4 bytes] Block count (u32 LE)
For each block:
  [2 bytes] Label length (u16 LE)
  [N bytes] Label string
  [4 bytes] Instruction count (u32 LE)
  For each instruction:
    [1 byte] Opcode
    [4 bytes] Operand1 (i32 LE)
    [4 bytes] Operand2 (i32 LE)
    [4 bytes] Operand3 (i32 LE)
```

### Fingerprint (.fp)

Binary format:
```
[4 bytes] Magic: "FP01"
[4 bytes] Dimension (u32 LE)
[N bytes] Trit data (i8 per trit: -1, 0, +1)
```

## Testing

```bash
# Run all tests
zig build test

# Test specific module
zig test src/firebird/b2t_integration.zig
zig test src/firebird/wasm_parser.zig
```

## License

Apache-2.0

## References

- [Trinity VSA Library](https://github.com/gHashTag/trinity)
- [WebArena Benchmark](https://github.com/web-arena-x/webarena)
- [Vector Symbolic Architectures](https://arxiv.org/abs/2001.11797)

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**
