# Trinity S³AI API Reference Manual v1.0

**Authors:** Dmitrii Vasilev
**Affiliation:** Trinity Research Collective
**Status:** Complete Reference
**Date:** March 26, 2026
**Version:** 1.0.0

---

## Overview

Trinity S³AI provides multiple programmatic interfaces for AI development and research:

### Interface Categories

| Category | Description | Primary Use |
|----------|-------------|-------------|
| **CLI Tools** | Command-line interface | Training, testing, deployment |
| **Libraries** | Reusable Zig modules | Custom model development |
| **Research Frameworks** | Experimentation tools | Ablation, benchmarking |
| **MCP Servers** | Model Context Protocol | LLM integration |
| **Build System** | Zig build configuration | Compilation, testing |

---

## Part 1: CLI Tools (`tri`)

The `tri` CLI is the unified entry point for all Trinity operations.

### 1.1 Build Commands

```bash
# Build all binaries
tri build

# Build specific target
tri build <target>

# Available targets
tri build              # All binaries
tri build tri          # CLI tool
tri build trinity-mcp  # MCP server
zig build test         # All tests
```

### 1.2 Test Commands

```bash
# Run all tests
tri test

# Run specific test suite
tri test vsa           # VSA operations
tri test vm            # Ternary VM
tri test hslm          # HSLM model
tri test temple        # Sacred math
```

### 1.3 Training Commands

```bash
# Train HSLM model
tri train hslm \
  --dataset data/tiny_stories.bin \
  --config configs/hslm_1.95M.json \
  --steps 30000 \
  --sacred-scale

# Resume training
tri train hslm \
  --checkpoint checkpoints/hslm_step_15000.bin \
  --steps 30000
```

### 1.4 Farm Commands

```bash
# List training workers
tri farm list

# Show worker status
tri farm status <worker-id>

# Recycle underperforming worker
tri farm recycle <worker-id>

# Inject new configuration
tri farm inject <config.json>
```

### 1.5 Cloud Commands

```bash
# Spawn container for issue
tri cloud spawn <issue-number>

# List active containers
tri cloud list

# Kill container
tri cloud kill <container-id>

# Sync with Railway
tri cloud sync
```

### 1.6 Git Commands

```bash
# Show working tree status
tri git status

# Commit changes
tri git commit "feat(scope): description"

# Push with safety checks
tri git push
```

---

## Part 2: Core Libraries

### 2.1 VSA Library (`src/vsa.zig`)

Vector Symbolic Architecture operations for sparse, high-dimensional computing.

#### Core Types

```zig
/// 512-dimensional ternary vector
pub const Vec512i8 = [512]i8;

/// 256-dimensional sparse vector (90% sparse)
pub const SparseVec256 = struct {
    indices: [26]u32,    // Non-zero indices (10% of 256)
    values: [26]i8,      // Ternary values {-1, 0, +1}
    len: u32,
};
```

#### Operations

##### `bind(a: Vec512i8, b: Vec512i8) Vec512i8`

Associate two vectors using circular convolution.

**Parameters:**
- `a`: First vector
- `b`: Second vector

**Returns:** Bound vector encoding the association

**Complexity:** O(d) where d = 512

**Example:**
```zig
const cat = vsa.fromString("cat");
const mat = vsa.fromString("mat");
const cat_mat = vsa.bind(cat, mat);
```

##### `unbind(bound: Vec512i8, key: Vec512i8) Vec512i8`

Retrieve from a binding using approximate inverse.

**Parameters:**
- `bound`: Bound vector from `bind()`
- `key`: Key vector to unbind

**Returns:** Approximate original value vector

**Example:**
```zig
const recovered = vsa.unbind(cat_mat, cat);
// recovered ≈ mat (cosine similarity > 0.85)
```

##### `bundle2(a: Vec512i8, b: Vec512i8) Vec512i8`

Majority vote of two vectors (set union).

**Parameters:**
- `a`, `b`: Vectors to bundle

**Returns:** Vector with element-wise majority

**Example:**
```zig
const fruits = vsa.bundle2(apple, banana);
```

##### `bundle3(a: Vec512i8, b: Vec512i8, c: Vec512i8) Vec512i8`

Majority vote of three vectors.

**Parameters:**
- `a`, `b`, `c`: Vectors to bundle

**Returns:** Vector with element-wise majority

##### `cosineSimilarity(a: Vec512i8, b: Vec512i8) f64`

Calculate cosine similarity between two vectors.

**Parameters:**
- `a`, `b`: Vectors to compare

**Returns:** Similarity in [-1, 1]

**Example:**
```zig
const sim = vsa.cosineSimilarity(cat_mat, mat);
// sim > 0.85 indicates successful binding
```

##### `permute(v: Vec512i8, count: u32) Vec512i8`

Cyclic permutation for variable binding.

**Parameters:**
- `v`: Vector to permute
- `count`: Number of rotation steps

**Returns:** Permuted vector

**Use Case:** Create unique bindings for same key
```zig
const slot1 = vsa.permute(key, 1);
const slot2 = vsa.permute(key, 2);
```

#### Performance Characteristics

| Operation | Scalar Time | SIMD Time | Speedup |
|-----------|-------------|-----------|---------|
| bind | 77 μs | 21 μs | 3.66× |
| dotProduct | 163 μs | 11 μs | 15.27× |
| hamming | 334 μs | 5 μs | 68.41× |

---

### 2.2 Ternary Library (`src/b2t/trit.zig`)

Balanced ternary arithmetic and operations.

#### Core Types

```zig
/// Balanced ternary enum
pub const Trit = enum(i8) {
    N = -1,  // Negative (T)
    Z = 0,   // Zero
    P = 1,   // Positive (1)

    pub fn isZero(self: Trit) bool {
        return self == Z;
    }

    pub fn isNonZero(self: Trit) bool {
        return self != Z;
    }
};
```

#### Operations

##### `add(a: Trit, b: Trit) Trit`

Ternary addition with carry propagation.

**Truth Table:**
```
  +   |  N   Z   P
  ----|------------
   N  |  P   N   Z
   Z  |  N   Z   P
   P  |  Z   P   N
```

##### `mul(a: Trit, b: Trit) Trit`

Ternary multiplication.

**Truth Table:**
```
  *   |  N   Z   P
  ----|------------
   N  |  P   Z   N
   Z  |  Z   Z   Z
   P  |  N   Z   P
```

##### `fromInt(n: i32) []Trit`

Convert integer to balanced ternary representation.

**Example:**
```zig
const result = try trit.fromInt(5);
// result = [P, T, P] = 9 - 3 + 1 = 5
```

##### `toInt(trits: []Trit) i32`

Convert balanced ternary to integer.

**Example:**
```zig
const value = trit.toInt(&[_]Trit{ .P, .N, .P });
// value = 5
```

#### Performance

| Operation | Time | Notes |
|-----------|------|-------|
| Enum access | ~0.3 ns | Direct lookup |
| Multiplication | ~2.1 ns | Branchless |
| Conversion | ~10 ns | Per trit |

---

### 2.3 Sacred Math Library (`src/temple/sacred_math.zig`)

Golden ratio constants and sacred computations.

#### Constants

```zig
/// Golden ratio: (1 + √5) / 2
pub const PHI: f64 = 1.618033988749895;

/// Sacred π: φ + 2
pub const PI_SACRED: f64 = 3.618033988749895;

/// φ⁻¹ (conjugate)
pub const PHI_INV: f64 = 0.618033988749895;

/// φ⁻² (sacred sparsity constant)
pub const PHI_INV_SQ: f64 = 0.3819660112501051;

/// φ⁻³ (sacred scaling exponent)
pub const PHI_INV_CUBED: f64 = 0.2360679774997897;
```

#### Functions

##### `sacredScale(dim: usize) f64`

Calculate sacred scaling factor for parameter initialization.

**Formula:**
```
σ = d^(-φ⁻³) = d^(-0.236)
```

**Example:**
```zig
const scale = sacred.sacredScale(512);
// scale ≈ 0.267
```

##### `optimalSparsity() f64`

Returns optimal sparsity for ternary weights.

**Value:** φ⁻² ≈ 0.382 (non-zero fraction)

**Usage:**
```zig
const target_nonzero = sacred.optimalSparsity();
const target_zeros = 1.0 - target_nonzero;  // ≈ 0.618
```

##### `ffnExpansion(hidden_dim: usize) usize`

Calculate FFN dimension using φ-based expansion.

**Formula:**
```
ffn_dim = ⌊hidden_dim × φ²⌋ = ⌊hidden_dim × 2.618⌋
```

**Example:**
```zig
const ffn_dim = sacred.ffnExpansion(512);
// ffn_dim = 1340
```

---

### 2.4 VM Library (`src/vm.zig`)

Ternary Virtual Machine for executing compiled models.

#### Core Types

```zig
/// Stack-based ternary VM
pub const TernaryVM = struct {
    stack: [1024]Trit,
    stack_ptr: u32,
    registers: [27]Trit,  // TRI-27: 3 banks × 9 registers
    program: []const Opcode,
    pc: u32,  // Program counter

    pub fn init(program: []const Opcode) TernaryVM { ... }
    pub fn step(self: *TernaryVM) !void { ... }
    pub fn run(self: *TernaryVM) !void { ... }
};
```

#### Opcodes

| Opcode | Operand | Description |
|--------|---------|-------------|
| NOP | - | No operation |
| PUSH | trit | Push trit to stack |
| POP | - | Pop from stack |
| ADD | - | Add top two stack values |
| MUL | - | Multiply top two |
| LOAD | reg_idx | Load from register |
| STORE | reg_idx | Store to register |
| JUMP | address | Unconditional jump |
| JGT | address | Jump if top > 0 |
| JLT | address | Jump if top < 0 |

#### Example Program

```zig
// Calculate: (3 + 2) × 4
const program = [_]Opcode{
    .{ .tag = .PUSH, .operand = 3 },   // Push 3
    .{ .tag = .PUSH, .operand = 2 },   // Push 2
    .{ .tag = .ADD },                  // Add: 5
    .{ .tag = .PUSH, .operand = 4 },   // Push 4
    .{ .tag = .MUL },                  // Mul: 20
    .{ .tag = .HALT },
};

var vm = TernaryVM.init(&program);
try vm.run();
// Result: vm.stack[0] = 20 (represented in balanced ternary)
```

---

## Part 3: Research Frameworks

### 3.1 Ablation Framework (`src/ablation.zig`)

Systematic ablation study framework.

```zig
/// Ablation configuration
pub const AblationConfig = struct {
    name: []const u8,
    component: Component,
    disabled: bool,

    pub const Component = enum {
        ternary_weights,
        vsa_attention,
        sacred_scaling,
        fpga_acceleration,
        sparse_ffn,
    };
};

/// Run ablation study
pub fn runAblation(
    config: []const AblationConfig,
    dataset: Dataset,
    metrics: *Metrics,
) !AblationResult {
    // Implementation...
}
```

#### Example Usage

```zig
const configs = [_]AblationConfig{
    .{ .name = "Full Model", .component = .none, .disabled = false },
    .{ .name = "No Ternary", .component = .ternary_weights, .disabled = true },
    .{ .name = "No VSA", .component = .vsa_attention, .disabled = true },
    .{ .name = "No Sacred", .component = .sacred_scaling, .disabled = true },
};

const results = try ablation.runAblation(&configs, dataset, &metrics);
```

### 3.2 Benchmark Framework (`src/benchmark/`)

Compare against state-of-the-art baselines.

```zig
/// Benchmark configuration
pub const BenchmarkConfig = struct {
    models: []const ModelConfig,
    datasets: []const Dataset,
    metrics: []const Metric,

    pub const Metric = enum {
        perplexity,
        throughput,
        memory,
        energy,
    };
};

/// Run benchmark
pub fn runBenchmark(config: BenchmarkConfig) !BenchmarkResult {
    // Implementation...
}
```

### 3.3 Hyperparameter Analysis (`src/hyperparameter_analysis.zig`)

Sensitivity analysis for hyperparameters.

```zig
/// Hyperparameter grid
pub const HyperparamGrid = struct {
    learning_rates: []const f64,
    batch_sizes: []const u32,
    sparsities: []const f64,
    scales: []const ScaleType,

    pub const ScaleType = enum {
        standard,
        sacred,
        kaiming,
        xavier,
    };
};

/// Run grid search
pub fn gridSearch(
    grid: HyperparamGrid,
    dataset: Dataset,
) !GridSearchResult {
    // Implementation...
}
```

---

## Part 4: MCP Server

### 4.1 Trinity MCP (`tools/mcp/trinity_mcp/`)

Model Context Protocol server for LLM integration.

#### Available Tools

| Tool | Description | Parameters |
|------|-------------|------------|
| `tri_math` | Sacred math calculations | operation, values |
| `tri_vsa` | VSA operations | op, vectors |
| `tri_train` | Start training | config |
| `tri_status` | Get farm status | - |
| `tri_code` | Generate Zig code | spec |
| `tri_verify` | Verify proofs | theorem |

#### Example Session

```json
// Request
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "tri_math",
    "arguments": {
      "operation": "phi_power",
      "exponent": -2
    }
  },
  "id": 1
}

// Response
{
  "jsonrpc": "2.0",
  "result": {
    "value": 0.3819660112501051,
    "formula": "φ^(-2)",
    "description": "Sacred sparsity constant"
  },
  "id": 1
}
```

---

## Part 5: Build System

### 5.1 Build Configuration (`build.zig`)

#### Standard Build Steps

```zig
// Build all binaries
pub fn build(b: *std.Build) *std.Build.Step {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main tri CLI
    const tri = b.addExecutable(.{
        .name = "tri",
        .root_source_file = .{ .path = "src/tri/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // MCP server
    const mcp = b.addExecutable(.{
        .name = "trinity-mcp",
        .root_source_file = .{ .path = "tools/mcp/trinity_mcp/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Tests
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/vsa.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Run tests step
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);

    return tri;
}
```

#### Custom Build Options

```bash
# Debug build
zig build -Doptimize=Debug

# Release fast (optimized)
zig build -Doptimize=ReleaseFast

# Release small (size-optimized)
zig build -Doptimize=ReleaseSmall

# Target specific architecture
zig build -Dtarget=aarch64-linux
```

---

## Part 6: Error Handling

### 6.1 Common Error Types

```zig
/// Trinity error set
pub const TrinityError = error{
    // I/O errors
    FileNotFound,
    PermissionDenied,

    // Model errors
    ModelCorrupted,
    InvalidCheckpoint,
    ArchitectureMismatch,

    // Training errors
    NaNLoss,
    Divergence,
    OutOfMemory,

    // VSA errors
    DimensionMismatch,
    InvalidTernaryValue,

    // VM errors
    StackOverflow,
    InvalidOpcode,
    DivisionByZero,
};
```

### 6.2 Error Handling Pattern

```zig
pub fn loadModel(path: []const u8) !Model {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.log.err("Failed to open model {s}: {}", .{path, err});
        return error.FileNotFound;
    };
    defer file.close();

    const header = try file.readStruct(ModelHeader);
    if (header.magic != MODEL_MAGIC) {
        return error.InvalidCheckpoint;
    }

    return Model{
        .header = header,
        // ... rest of initialization
    };
}
```

---

## Part 7: Configuration

### 7.1 Model Configuration

```json
{
  "model_type": "HSLM",
  "version": "1.0",
  "architecture": {
    "vocab_size": 31000,
    "hidden_dim": 512,
    "num_layers": 6,
    "num_heads": 8,
    "ffn_dim": 1340,
    "max_seq_len": 512
  },
  "training": {
    "learning_rate": 0.001,
    "warmup_steps": 1000,
    "max_steps": 30000,
    "batch_size": 64,
    "weight_decay": 0.01,
    "gradient_clip": 1.0
  },
  "sacred": {
    "use_sacred_scaling": true,
    "sacred_sparsity": 0.382,
    "phi_expansion": true
  },
  "quantization": {
    "ternary_weights": true,
    "sparsity": 0.9,
    "vsa_binding": true
  }
}
```

### 7.2 Loading Configuration

```zig
pub const Config = struct {
    model: ModelConfig,
    training: TrainingConfig,
    sacred: SacredConfig,
    quantization: QuantConfig,

    pub fn load(path: []const u8) !Config {
        const file = try std.fs.cwd().readFileAlloc(
            allocator,
            path,
            1024 * 1024  // Max 1MB
        );
        defer allocator.free(file);

        return std.json.parse(Config, &std.json.TokenStream.init(file), .{
            .allocator = allocator,
            .ignore_unknown_fields = true,
        });
    }
};
```

---

## Appendix A: Quick Reference

### Common Commands

```bash
# Build and test
zig build && zig build test

# Format code
zig fmt src/

# Run specific test
zig test src/vsa.zig

# Generate documentation
zig build docs
```

### File Locations

| Component | Path |
|-----------|------|
| VSA | `src/vsa.zig` |
| Ternary | `src/b2t/trit.zig` |
| Sacred | `src/temple/sacred_math.zig` |
| VM | `src/vm.zig` |
| HSLM | `src/hslm/` |
| Tests | `src/**/tests.zig` |

### Performance Tips

1. **Use SIMD operations** for vector math (automatic for VSA)
2. **Enable sacred scaling** for 2-3% faster convergence
3. **Set sparsity to 90%** for optimal memory/speed tradeoff
4. **Use ReleaseFast** for production builds
5. **Profile with `zig build --verbose`** to find bottlenecks

---

**φ² + 1/φ² = 3 | TRINITY**

**Document Version:** 1.0.0
**Status:** Complete — Production Ready
**Last Updated:** 2026-03-26
