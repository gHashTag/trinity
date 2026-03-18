# HDC Encoder Optimization Report

**Date**: 2026-02-05  
**Status**: EXPERIMENT COMPLETE  
**Target**: +30% accuracy improvement  
**Result**: N-grams hurt performance on small datasets

---

## Overview

Implemented EnhancedTextEncoder with n-grams and TF-IDF weighting to improve multi-task classification accuracy. The experiment revealed that n-gram features hurt performance on small datasets.

## Implementation

### EnhancedTextEncoder Features

1. **Bigram encoding**: Bind consecutive token pairs
2. **Trigram encoding**: Bind consecutive token triplets  
3. **TF-IDF weighting**: Weight tokens by inverse document frequency
4. **Configurable weights**: Adjustable n-gram contribution

### Code Location

- `src/phi-engine/hdc/multi_task_learner.zig` - EnhancedTextEncoder struct
- `src/phi-engine/hdc/demo_encoder_benchmark.zig` - Benchmark comparison

## Benchmark Results

### Dataset

| Task | Classes | Training Samples |
|------|---------|------------------|
| Sentiment | 3 (positive, negative, neutral) | 26 |
| Topic | 3 (technology, sports, finance) | 24 |
| Formality | 2 (formal, informal) | 16 |
| **Total** | 8 | 66 |

Test set: 12 samples with ground truth labels.

### Basic Encoder (Unigram + Position)

| Task | Correct | Total | Accuracy |
|------|---------|-------|----------|
| Sentiment | 6 | 12 | 50.0% |
| Topic | 3 | 12 | 25.0% |
| Formality | 7 | 12 | 58.3% |
| **Average** | - | - | **44.4%** |

### Enhanced Encoder (N-grams + TF-IDF)

| Task | Correct | Total | Accuracy |
|------|---------|-------|----------|
| Sentiment | 4 | 12 | 33.3% |
| Topic | 1 | 12 | 8.3% |
| Formality | 5 | 12 | 41.7% |
| **Average** | - | - | **27.8%** |

### Comparison

| Metric | Basic | Enhanced | Delta |
|--------|-------|----------|-------|
| Sentiment | 50.0% | 33.3% | -16.7% |
| Topic | 25.0% | 8.3% | -16.7% |
| Formality | 58.3% | 41.7% | -16.7% |
| **Average** | **44.4%** | **27.8%** | **-16.7%** |

**Result**: Enhanced encoder performed WORSE (-16.7%)

## Interference Check

| Task Pair | Max Similarity | Avg Similarity | Status |
|-----------|----------------|----------------|--------|
| formality vs topic | 0.0141 | 0.0091 | ✓ PASS |
| formality vs sentiment | 0.0155 | 0.0072 | ✓ PASS |
| topic vs sentiment | 0.0165 | 0.0097 | ✓ PASS |

**Interference < 0.05 for ALL task pairs (VERIFIED)**

## Analysis

### Why N-grams Hurt Performance

1. **Small dataset problem**: With only 66 training samples, n-grams create sparse features that don't generalize
2. **Noise amplification**: Bigrams/trigrams add dimensions that are mostly noise on small data
3. **Overfitting**: N-gram features overfit to training vocabulary patterns

### When N-grams Help

N-grams typically improve performance when:
- Training corpus > 1000 samples
- Vocabulary overlap between classes is high
- Phrase-level semantics matter (e.g., "not good" vs "good")

### Recommendations

1. **For small datasets (< 100 samples)**: Use basic unigram encoder
2. **For medium datasets (100-1000 samples)**: Use bigrams only, no trigrams
3. **For large datasets (> 1000 samples)**: Full n-gram + TF-IDF

## Key Findings

1. **Task independence maintained**: Interference < 0.05 regardless of encoder
2. **Basic encoder is better for small data**: Simpler features generalize better
3. **N-grams need large corpora**: The +30% target requires more training data

## Files

- `src/phi-engine/hdc/multi_task_learner.zig` - EnhancedTextEncoder implementation
- `src/phi-engine/hdc/demo_encoder_benchmark.zig` - Benchmark demo

## Run Benchmark

```bash
cd /workspaces/trinity
zig build-exe src/phi-engine/hdc/demo_encoder_benchmark.zig
./demo_encoder_benchmark
```

## Conclusion

The +30% accuracy target was NOT achieved. N-gram encoding hurts performance on small datasets. The basic unigram encoder remains the better choice for datasets < 100 samples.

**Positive outcome**: Task interference remains < 0.05, confirming HDC multi-task independence is robust to encoder changes.

---

**φ² + 1/φ² = 3 | ENCODER EXPERIMENT COMPLETE**
