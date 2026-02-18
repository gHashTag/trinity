# Archive Analysis & Migration Plan

**Goal:** Find useful logic in archive/ and migrate to trinity-nexus
**Date:** 2026-02-18
**Priority:** HIGH

---

## 📊 Archive Structure Analysis

### ✅ Useful Code (Should Migrate)

#### 1. ML/AI Components
**Location:** `archive/implementations/zig/src/ml/`
**Files:**
- `model.zig` - ML model architecture
- `tensor.zig` - Tensor operations
- `trainer.zig` - Training loop
- `quantum.zig` - Quantum-inspired operations

**Migration Target:** `trinity-nexus/core/ml/`
**Status:** ⏳ Not migrated
**Priority:** HIGH (for coder model)

#### 2. Attention Mechanism
**Location:** `archive/implementations/zig/src/attention.zig`
**Useful for:** Transformer models
**Migration Target:** `trinity-nexus/core/nn/`
**Status:** ⏳ Not migrated
**Priority:** HIGH

#### 3. Optimizers
**Location:** `archive/implementations/zig/src/optimizers.zig`
**Useful for:** Training optimization
**Migration Target:** `trinity-nexus/core/optimizers/`
**Status:** ⏳ Not migrated
**Priority:** MEDIUM

#### 4. Quantization
**Location:** `archive/implementations/zig/src/quantization.zig`
**Useful for:** Model compression
**Migration Target:** `trinity-nexus/core/quantization/`
**Status:** ⏳ Not migrated
**Priority:** HIGH (for ternary weights)

#### 5. Benchmarks
**Location:** `archive/old/benchmarks/`
**Files:**
- `bench_math.zig` - Math benchmarks
- `bench_compression.zig` - Compression benchmarks
- `ai_models_comparison.zig` - Model comparison

**Migration Target:** `trinity-nexus/benchmarks/`
**Status:** ✅ Already migrated
**Priority:** LOW (already done)

---

### 🗑️ Deprecated Code (Keep in Archive)

#### 1. Old Frontend
- `translator-app/` - Deprecated translation tool
- `frontend/` - Old frontend experiments

#### 2. Old Demos
- `demos/` - Old demo code
- `experiments/` - Old experiments

#### 3. Marketing/Speculation
- `museum/marketing/` - Marketing materials
- `museum/speculation/` - Speculative code

#### 4. Legacy Agents
- `museum/legacy_agents/` - Old agent implementations

---

## 🎯 Migration Plan

### Phase 1: ML Components (HIGH PRIORITY)

#### Task 1: Migrate tensor.zig
**Source:** `archive/implementations/zig/src/ml/tensor.zig`
**Target:** `trinity-nexus/core/ml/tensor.zig`
**Changes:**
- Update imports for trinity-nexus structure
- Add tests
- Integrate with VSA

#### Task 2: Migrate model.zig
**Source:** `archive/implementations/zig/src/ml/model.zig`
**Target:** `trinity-nexus/core/ml/model.zig`
**Changes:**
- Update for ternary weights
- Add VSA integration
- Support .vibee spec generation

#### Task 3: Migrate trainer.zig
**Source:** `archive/implementations/zig/src/ml/trainer.zig`
**Target:** `trinity-nexus/core/ml/trainer.zig`
**Changes:**
- Add distributed training support
- Integrate with $TRI rewards
- Add progress tracking

#### Task 4: Migrate quantum.zig
**Source:** `archive/implementations/zig/src/ml/quantum.zig`
**Target:** `trinity-nexus/core/ml/quantum.zig`
**Changes:**
- Keep as quantum-inspired (not real quantum)
- Add VSA quantum operations
- Support symbolic reasoning

---

### Phase 2: Neural Network Components

#### Task 5: Migrate attention.zig
**Source:** `archive/implementations/zig/src/attention.zig`
**Target:** `trinity-nexus/core/nn/attention.zig`
**Changes:**
- Ternary attention mechanism
- VSA-based attention
- SIMD optimization

#### Task 6: Migrate optimizers.zig
**Source:** `archive/implementations/zig/src/optimizers.zig`
**Target:** `trinity-nexus/core/optimizers/`
**Changes:**
- Add ternary-aware optimizers
- Φ-based learning rates
- Integrate with VSA

#### Task 7: Migrate quantization.zig
**Source:** `archive/implementations/zig/src/quantization.zig`
**Target:** `trinity-nexus/core/quantization/`
**Changes:**
- Ternary quantization (1.58 bits)
- Φ-based quantization
- Lossless compression

---

### Phase 3: Integration

#### Task 8: Create ML spec
**Target:** `specs/tri/ml_pipeline.vibee`
**Content:**
- Tensor operations spec
- Model training spec
- Optimizer spec
- Quantization spec

#### Task 9: Generate code from spec
**Command:** `zig build vibee -- gen specs/tri/ml_pipeline.vibee`
**Output:** `generated/ml_pipeline.zig`

#### Task 10: Write tests
**Target:** `trinity-nexus/core/ml/tests/`
**Tests:**
- Tensor operations
- Model forward/backward
- Optimizer convergence
- Quantization accuracy

---

## 📊 Migration Status

| Component | Source | Target | Status | Priority |
|-----------|--------|--------|--------|----------|
| Tensor | archive/.../ml/tensor.zig | nexus/core/ml/ | ⏳ | HIGH |
| Model | archive/.../ml/model.zig | nexus/core/ml/ | ⏳ | HIGH |
| Trainer | archive/.../ml/trainer.zig | nexus/core/ml/ | ⏳ | HIGH |
| Quantum | archive/.../ml/quantum.zig | nexus/core/ml/ | ⏳ | HIGH |
| Attention | archive/.../attention.zig | nexus/core/nn/ | ⏳ | HIGH |
| Optimizers | archive/.../optimizers.zig | nexus/core/optimizers/ | ⏳ | MEDIUM |
| Quantization | archive/.../quantization.zig | nexus/core/quantization/ | ⏳ | HIGH |

---

## 🎯 Success Criteria

1. ✅ All ML components migrated to trinity-nexus
2. ✅ Tests passing for all migrated code
3. ✅ .vibee specs created for ML pipeline
4. ✅ Code generated from specs
5. ✅ Integration with VSA working
6. ✅ Coder model can train

---

## 📝 Estimated Time

- **Phase 1 (ML):** 4-6 hours
- **Phase 2 (NN):** 3-4 hours
- **Phase 3 (Integration):** 2-3 hours
- **Total:** 9-13 hours

---

## 🚀 Next Steps

1. Start with `tensor.zig` migration
2. Create .vibee spec for tensors
3. Generate code and test
4. Continue with other components

---

**Status:** 📝 Plan Created
**Next:** Execute Phase 1, Task 1
**Owner:** VIBEE
