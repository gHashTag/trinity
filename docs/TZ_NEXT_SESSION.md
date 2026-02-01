# Technical Specification (TZ) for Next Agent Session

**Repository:** https://github.com/gHashTag/trinity
**Date:** 2026-02-01
**Author:** Ona AI Agent
**Sacred Formula:** V = n × 3^k × π^m × φ^p × e^q

---

## Current State Summary

### Completed Work

| Commit | Description | Tests |
|--------|-------------|-------|
| `332e11565` | TIER 2 JIT with SSA optimization and native x86-64 codegen | 42 |
| `8c79db838` | Register VM and NaN-boxed value system | 63 |
| `1d73333b9` | SIMD vectorization pass for array operations | 12 |
| `ce37c0754` | Ternary SIMD integration into JIT pipeline | 11 |

**Total Tests Passing:** 115+

### Performance Achieved

| Tier | Component | Performance |
|------|-----------|-------------|
| TIER 0 | Stack VM (Interpreter) | 75M ops/sec |
| TIER 1 | Register VM | 150M ops/sec (2x) |
| TIER 2 | SSA + Native x86-64 | 569M ops/sec (7.5x) |
| SIMD | Array Sum | 3.7x additional speedup |
| Ternary SIMD | Batch Accumulator | 35x faster |

---

## File Structure

```
src/vibeec/
├── JIT Core
│   ├── jit_tier2.zig          # SSA IR + Optimizer + SIMD integration
│   ├── bytecode_to_ssa.zig    # Stack bytecode → SSA converter
│   ├── ssa_native_codegen.zig # SSA → x86-64 native code
│   └── jit_e2e.zig            # End-to-end JIT pipeline
│
├── Register VM
│   ├── reg_vm.zig             # Register-based VM
│   ├── reg_compiler.zig       # AST → Register bytecode
│   └── reg_bytecode.zig       # Register bytecode format
│
├── NaN-boxing
│   ├── nan_value.zig          # NaN-boxed value representation
│   ├── nan_vm.zig             # NaN-boxed VM
│   └── nan_reg_vm.zig         # Combined NaN + Register VM
│
├── SIMD
│   ├── simd_vectorizer.zig    # Generic SIMD (Vec4i64)
│   ├── simd_ternary.zig       # Ternary SIMD operations
│   └── simd_ternary_optimized.zig # Optimized ternary SIMD
│
└── Benchmarks
    ├── opt_benchmark.zig
    ├── full_pipeline_benchmark.zig
    └── benchmark_ternary_vs_binary.zig
```

---

## Next Steps (Priority Order)

### [A] TIER 3 - Tracing JIT (RECOMMENDED)

**Complexity:** ★★★★★
**Potential:** 1B+ ops/sec (2x over TIER 2)

**Implementation Plan:**

1. **Trace Recording**
   - Instrument hot loops (execution count > 1000)
   - Record linear trace of executed instructions
   - Handle loop exits (guards)

2. **Trace Compilation**
   - Convert trace to SSA IR
   - Apply existing optimizations (constant folding, DCE)
   - Generate native code for trace

3. **Guard Handling**
   - Insert guard checks for type stability
   - Deoptimize to interpreter on guard failure
   - Implement on-stack replacement (OSR)

4. **Files to Create:**
   ```
   src/vibeec/tracing_jit.zig      # Trace recorder
   src/vibeec/trace_compiler.zig   # Trace → SSA → Native
   src/vibeec/osr.zig              # On-stack replacement
   specs/tri/tracing_jit.vibee     # Specification
   ```

### [B] ARM64 Native Codegen

**Complexity:** ★★★★☆
**Potential:** Cross-platform native execution

**Implementation Plan:**

1. Create `ssa_arm64_codegen.zig` mirroring x86-64 structure
2. Map SSA ops to ARM64 instructions
3. Handle ARM64 calling convention
4. Test on ARM64 hardware (Apple Silicon, Raspberry Pi)

### [C] E-Graph Optimization

**Complexity:** ★★★★☆
**Potential:** Optimal expression rewriting

**Implementation Plan:**

1. Implement e-graph data structure
2. Add rewrite rules for algebraic identities
3. Extract optimal expression from e-graph
4. Integrate with SSA optimization pipeline

---

## API Reference

### JITTier2 Usage

```zig
const jit = @import("jit_tier2.zig");

// Create JIT compiler
var compiler = jit.JITTier2.init(allocator);
defer compiler.deinit();

// Create SSA function
var func = jit.SSAFunction.init(allocator, "my_func");

// Emit instructions
const v1 = func.newValue();
func.emit(0, jit.SSAInstr.constInt(v1, 10));
const v2 = func.newValue();
func.emit(0, jit.SSAInstr.constInt(v2, 20));
const v3 = func.newValue();
func.emit(0, jit.SSAInstr.binop(.add, v3, v1, v2));
func.emit(0, jit.SSAInstr.ret(v3));

// Optimize
compiler.compile(&func);

// Get stats
const stats = compiler.getStats();
```

### SIMD Operations

```zig
// Generic SIMD
const sum = jit.JITTier2.VectorizedArrayOps.arraySum(&data);
const dot = jit.JITTier2.VectorizedArrayOps.dotProduct(&a, &b);

// Ternary SIMD
const Ternary = jit.JITTier2.TernarySIMD;
const result = Ternary.tryteAdd32(a, b);
var acc = Ternary.TryteAccumulator.init();
acc.add(trytes);
const final = acc.finalize();
```

### Native Code Generation

```zig
const codegen = @import("ssa_native_codegen.zig");

var gen = codegen.NativeCodegen.init(allocator);
defer gen.deinit();

const native_code = gen.compile(&ssa_func);
const result = native_code.execute();
```

---

## Testing Commands

```bash
# Test individual files
zig test src/vibeec/jit_tier2.zig
zig test src/vibeec/bytecode_to_ssa.zig
zig test src/vibeec/ssa_native_codegen.zig
zig test src/vibeec/simd_vectorizer.zig

# Run benchmarks
zig build-exe src/vibeec/ssa_native_codegen.zig -O ReleaseFast && ./ssa_native_codegen
zig build-exe src/vibeec/simd_vectorizer.zig -O ReleaseFast && ./simd_vectorizer

# Test all JIT files
for f in jit_tier2.zig bytecode_to_ssa.zig ssa_native_codegen.zig simd_vectorizer.zig; do
  zig test src/vibeec/$f
done
```

---

## Golden Chain Workflow

```
┌────┬──────────────────┬─────────────────────────────────────────┐
│  # │ LINK             │ DESCRIPTION                             │
├────┼──────────────────┼─────────────────────────────────────────┤
│  5 │ SPEC CREATE      │ Create .vibee specification             │
│  6 │ CODE GENERATE    │ Generate .zig from .vibee               │
│  7 │ TEST RUN         │ Run all tests                           │
│ 14 │ TOXIC VERDICT    │ 🔥 HARSH SELF-CRITICISM                 │
│ 15 │ TECH TREE SELECT │ 🌳 Choose next research                 │
│ 16 │ LOOP/EXIT        │ Decision: continue or EXIT              │
└────┴──────────────────┴─────────────────────────────────────────┘
```

---

## Critical Rules

1. **NEVER write .zig code manually** - Generate from .vibee specs
2. **Exception:** `src/vibeec/*.zig` compiler source is editable
3. **Always run tests** after any change
4. **Write TOXIC VERDICT** after each task
5. **Propose TECH TREE SELECT** with 3 options

---

## Contact

- Repository: https://github.com/gHashTag/trinity
- Documentation: `docs/architecture/JIT_OPTIMIZATION.md`

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**
