# CIFAR-10 Cross-Modal Validation Design v1.0

**Date:** 2026-03-26
**Issue:** #415
**Branch:** feat/issue-411-linear-types-ownership
**Purpose:** Design document for CIFAR-10 image classification with ternary HSLM

---

## Executive Summary

This document describes the design for implementing CIFAR-10 image classification using Trinity S³AI's ternary neural network (HSLM). This serves as cross-modal validation beyond language modeling.

**Target:** Demonstrate that ternary networks can achieve competitive accuracy on vision tasks.

---

## Part I: CIFAR-10 Dataset

### I.1 Dataset Specifications

| Property | Value |
|----------|--------|
| Classes | 10 (airplane, automobile, bird, cat, deer, dog, frog, horse, ship, truck) |
| Images | 60,000 total (50,000 train, 10,000 test) |
| Image Size | 32×32 RGB pixels |
| Format | Binary files (CIFAR-10 binary version) |
| Per-Class | 6,000 images (5,000 train, 1,000 test) |

### I.2 Data Layout

**File Format:**
```
data_batch_1.bin  (Training batch 1: 10,000 images, ~160MB)
data_batch_2.bin  (Training batch 2: 10,000 images)
data_batch_3.bin  (Training batch 3: 10,000 images)
data_batch_4.bin  (Training batch 4: 10,000 images)
data_batch_5.bin  (Training batch 5: 10,000 images)
test_batch.bin     (Test set: 10,000 images)
```

**Per Image:**
```
1 byte: label (0-9)
3072 bytes: image (32×32×3 = 3072, row-major, RRR...GGG...BBB...)
```

---

## Part II: Architecture Design

### II.1 Model Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TERNARY CIFAR-10 CLASSIFIER                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Input: CIFAR-10 image [32×32×3]                                            │
│         ┌────────────┐                                                      │
│         │  Preprocess │                                                      │
│         │  Normalize  │                                                      │
│         └─────┬──────┘                                                      │
│               │                                                             │
│               ▼                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  PATCH EMBEDDING (Conv1D or Linear)                                  │    │
│  │  Input: [3072] → Output: [embed_dim]                                 │    │
│  │  Weights: Ternary {-1, 0, +1}                                        │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│               │                                                             │
│               ▼                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  HSLM BACKBONE (6 Trinity Blocks)                                    │    │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │    │
│  │  │  Block 1: Multi-head Attention (3 heads) + FFN                    │  │    │
│  │  │  Block 2: Multi-head Attention (3 heads) + FFN                    │  │    │
│  │  │  Block 3: Multi-head Attention (3 heads) + FFN                    │  │    │
│  │  │  Block 4: Multi-head Attention (3 heads) + FFN                    │  │    │
│  │  │  Block 5: Multi-head Attention (3 heads) + FFN                    │  │    │
│  │  │  Block 6: Multi-head Attention (3 heads) + FFN                    │  │    │
│  │  └─────────────────────────────────────────────────────────────────┘  │    │
│  │  Sequence Length: 32 patches × 32 patches = 1024 tokens              │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│               │                                                             │
│               ▼                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  CLASSIFICATION HEAD                                                 │    │
│  │  Global Average Pooling → Linear → Softmax                           │    │
│  │  Output: [10] class probabilities                                     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### II.2 Simplified Architecture (for faster iteration)

```
Input: [3072] (flattened 32×32×3)
  ↓
Linear Layer: [3072] → [512] (ternary weights)
  ↓
ReLU Activation
  ↓
Linear Layer: [512] → [256] (ternary weights)
  ↓
ReLU Activation
  ↓
Linear Layer: [256] → [10] (ternary weights)
  ↓
Softmax → [10] class probabilities
```

**Parameters:** ~1.7M (vs HSLM's 1.95M for language)

---

## Part III: Implementation Plan

### III.1 File Structure

```
src/vision/
├── cifar10_loader.zig      # CIFAR-10 binary file parser
├── cifar10_model.zig       # Model architecture definition
├── cifar10_train.zig       # Training loop
├── cifar10_eval.zig        # Evaluation and metrics
└── benchmarks.zig          # Vision benchmarks

src/vsa/
└── vision_ops.zig          # VSA operations for image embeddings
```

### III.2 Module Specifications

#### Module 1: CIFAR-10 Data Loader

```zig
// src/vision/cifar10_loader.zig
const std = @import("std");

pub const CIFAR10Image = struct {
    data: [3072]u8,  // 32×32×3
    label: u8,         // 0-9
};

pub const CIFAR10Batch = struct {
    images: std.ArrayList(CIFAR10Image),
    batch_size: usize,

    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8, batch_size: usize) !CIFAR10Batch {
        // Parse CIFAR-10 binary file
        // Return batch of images
    }

    pub fn normalize(self: *CIFAR10Batch) !void {
        // Normalize pixel values to [-1, 1]
        // Formula: pixel / 127.5 - 1.0
    }
};
```

#### Module 2: Model Architecture

```zig
// src/vision/cifar10_model.zig
const hslm = @import("hslm/model.zig");

pub const CIFAR10Config = struct {
    patch_size: usize = 8,        // 8×8 patches
    num_patches: usize = 16,       // 4×4 grid over 32×32
    embed_dim: usize = 192,        // Reduced from 243 for vision
    num_blocks: usize = 4,         // Reduced from 6 for faster training
    num_heads: usize = 3,
    num_classes: usize = 10,
};

pub const CIFAR10Model = struct {
    backbone: hslm.HSLM,
    classifier: ClassifierHead,

    pub fn init(allocator: std.mem.Allocator, config: CIFAR10Config) !CIFAR10Model {
        // Initialize HSLM backbone
        // Initialize classifier head
    }

    pub fn forward(self: *CIFAR10Model, images: []const CIFAR10Image) ![10]f32 {
        // 1. Convert images to sequence of patches
        // 2. Run through HSLM backbone
        // 3. Classify through head
        // 4. Return class probabilities
    }
};
```

#### Module 3: Training Loop

```zig
// src/vision/cifar10_train.zig
pub const CIFAR10Trainer = struct {
    model: CIFAR10Model,
    optimizer: Optimizer,
    learning_rate: f64,

    pub fn trainEpoch(self: *CIFAR10Trainer, batch: CIFAR10Batch) !TrainMetrics {
        // 1. Forward pass
        // 2. Compute loss (cross-entropy)
        // 3. Backward pass (STE gradients)
        // 4. Update weights
    }

    pub fn validate(self: *CIFAR10Trainer, test_batches: []CIFAR10Batch) !ValidationMetrics {
        // Run on test set
        // Compute accuracy, loss
    }
};
```

---

## Part IV: Training Configuration

### IV.1 Hyperparameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Optimizer | Adam (or Sacred SGD) | Standard for vision |
| Learning Rate | 0.001 (sacred cosine schedule) | From HSLM |
| Batch Size | 128 | Standard for CIFAR-10 |
| Epochs | 100 | Typical for CIFAR-10 |
| Weight Decay | 0.0001 | Regularization |
| Label Smoothing | 0.1 | Prevents overconfidence |

### IV.2 Data Augmentation

To improve generalization:
1. Random horizontal flip (50% probability)
2. Random crop (with padding to 40×40, crop to 32×32)
3. Cutout (random masking of 16×16 patches)
4. AutoAugment (policy learned from data)

---

## Part V: Expected Results

### V.1 Baseline Comparisons

| Model | Accuracy | Params | Notes |
|-------|----------|--------|-------|
| ResNet-18 (FP32) | 95.2% | 11M | Standard baseline |
| ResNet-18 (1.58-bit) | 92.1% | 11M | BitNet b1.58 |
| Our Ternary HSLM (target) | >85% | 1.7M | Simpler model |

### V.2 Success Criteria

- **Minimum:** 80% accuracy (demonstrates ternary networks work for vision)
- **Target:** 85% accuracy (competitive with simpler baselines)
- **Stretch:** 88% accuracy (approaches BitNet performance)

---

## Part VI: Evaluation Metrics

### VI.1 Primary Metrics

1. **Top-1 Accuracy** — Primary metric for CIFAR-10
2. **Top-5 Accuracy** — Not applicable for CIFAR-10 (10 classes)
3. **Training Time** — Wall-clock time to convergence
4. **Inference Speed** — Images/second

### VI.2 Secondary Metrics

1. **Memory Usage** — Peak RAM during training
2. **Model Size** — Disk size of trained model
3. **Energy Efficiency** — Power per inference (if FPGA)

---

## Part VII: Implementation Phases

### Phase 1: Data Loading (Week 1)

**Tasks:**
1. Implement CIFAR-10 binary file parser
2. Create data normalization
3. Implement train/val split
4. Add data augmentation functions

**Deliverable:** Working data loader with unit tests

### Phase 2: Model Architecture (Week 1-2)

**Tasks:**
1. Implement simplified linear model (for baseline)
2. Implement patch embedding layer
3. Integrate with existing HSLM blocks
4. Add classification head

**Deliverable:** Trainable CIFAR-10 model

### Phase 3: Training Loop (Week 2)

**Tasks:**
1. Implement cross-entropy loss
2. Add Adam optimizer (or sacred SGD)
3. Implement learning rate schedule
4. Add checkpoint saving/loading

**Deliverable:** Complete training pipeline

### Phase 4: Evaluation (Week 3)

**Tasks:**
1. Implement accuracy computation
2. Create confusion matrix
3. Generate training curves
4. Compare with baselines

**Deliverable:** Publication-ready results

---

## Part VIII: Research Questions

### VIII.1 Questions to Answer

1. **Q1:** Can ternary neural networks achieve competitive accuracy on vision tasks?
   - Hypothesis: Yes, >80% accuracy achievable

2. **Q2:** Does sacred scaling benefit vision training?
   - Hypothesis: Yes, 1.5× faster convergence

3. **Q3:** How does ternary quantization affect vision feature learning?
   - Hypothesis: Ternary weights preserve coarse features

### VIII.2 Ablation Studies

1. **Patch Size Impact:** 4×4 vs 8×8 vs 16×16
2. **Sequence Length:** Full vs reduced (1024 → 256)
3. **Number of Blocks:** 4 vs 6 vs 8
4. **Embedding Dimension:** 128 vs 192 vs 243

---

## Part IX: Timeline

| Week | Milestone | Deliverable |
|------|-----------|------------|
| 1 | Data loader complete | `src/vision/cifar10_loader.zig` |
| 1-2 | Model architecture complete | `src/vision/cifar10_model.zig` |
| 2 | Training loop complete | `src/vision/cifar10_train.zig` |
| 3 | First results (baseline model) | Accuracy report |
| 4 | Full ablation studies | Complete paper figures |
| 5 | NeurIPS submission | Camera-ready paper |

---

## Part X: Code Templates

### X.1 Main Entry Point

```zig
// src/vision/main.zig
const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Load training data
    const train_batch = try CIFAR10Batch.loadFromFile(allocator, "data/cifar-10/data_batch_1.bin", 128);
    defer train_batch.deinit();

    // Initialize model
    var model = try CIFAR10Model.init(allocator, CIFAR10Config{});
    defer model.deinit();

    // Train
    var trainer = try CIFAR10Trainer.init(allocator, &model, .{
        .learning_rate = 0.001,
        .batch_size = 128,
    });
    defer trainer.deinit();

    // Training loop
    var epoch: usize = 0;
    while (epoch < 100) : (epoch += 1) {
        const metrics = try trainer.trainEpoch(train_batch);
        std.log.info("Epoch {d}: loss={d:.4}, acc={d:.2}%", .{ epoch, metrics.loss, metrics.accuracy });

        if (epoch % 10 == 0) {
            try trainer.saveCheckpoint("checkpoints/cifar10_epoch_{}.zig".format(epoch));
        }
    }

    std.log.info("Training complete!", .{});
}
```

---

## Conclusion

This design provides:
1. **Clear path** from data loading to evaluation
2. **Realistic targets** based on current ternary network research
3. **Phased approach** for incremental development
4. **Publication metrics** aligned with top venues

**Next Action:** Implement Phase 1 (Data Loading)

**φ² + 1/φ² = 3 | TRINITY**
