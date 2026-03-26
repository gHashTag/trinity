# Statistical Validation Framework — Trinity S³AI

**Version:** 1.0
**Date:** March 26, 2026
**Purpose:** Define rigorous statistical protocols for all experimental results

---

## Overview

This document establishes the statistical validation framework for Trinity S³AI experimental results. All experiments reported in publications must follow these protocols to ensure reproducibility and statistical significance.

---

## 1. Multi-Run Protocol

### 1.1 Minimum Run Count

**Standard**: All experiments require **minimum 10 runs** with different random seeds.

```zig
// src/hslm/statistics.zig
pub const STANDARD_SEEDS = [_]u32{
    42, 123, 456, 789, 1024, 2048, 4096, 8192, 16384, 32768
};
```

**Rationale**: 10 runs provide 95% confidence interval with margin of error ≈ 0.5σ for normally distributed metrics.

### 1.2 Seed Documentation

Every experimental run must log:
- Seed value
- Start timestamp
- End timestamp
- Final metric value
- Training curve snapshots

---

## 2. Confidence Intervals

### 2.1 95% Confidence Interval Calculation

All reported metrics must include 95% confidence intervals:

```zig
pub fn confidenceInterval(values: []const f32) struct { lower: f32, upper: f32 } {
    const n = values.len;
    const mean_val = mean(values);
    const std_val = stdDev(values);
    const margin = 1.96 * std_val / @sqrt(@as(f32, @floatFromInt(n)));
    return .{ .lower = mean_val - margin, .upper = mean_val + margin };
}
```

### 2.2 Reporting Format

**Format**: `metric = mean ± 1.96σ (95% CI: [lower, upper])`

**Example**: `PPL = 124.1 ± 2.1 (95% CI: [122.0, 126.2])`

---

## 3. Statistical Significance Testing

### 3.1 Two-Sample t-Test

For comparing two experimental configurations:

```zig
pub fn tTest(group1: []const f32, group2: []const f32) struct { p_value: f32, t_stat: f32 } {
    const n1 = group1.len;
    const n2 = group2.len;
    const mean1 = mean(group1);
    const mean2 = mean(group2);
    const var1 = variance(group1);
    const var2 = variance(group2);

    // Pooled standard deviation
    const sp = @sqrt(((n1 - 1) * var1 + (n2 - 1) * var2) / @as(f32, @floatFromInt(n1 + n2 - 2)));

    // t-statistic
    const t_stat = (mean1 - mean2) / (sp * @sqrt(1.0 / @as(f32, @floatFromInt(n1)) + 1.0 / @as(f32, @floatFromInt(n2))));

    // p-value (two-tailed) — approximated
    const p_value = tCDF(t_stat, df);

    return .{ .p_value = p_value, .t_stat = t_stat };
}
```

### 3.2 Significance Thresholds

- **Significant**: p < 0.05 (*)
- **Highly significant**: p < 0.01 (**)
- **Very highly significant**: p < 0.001 (***)

### 3.3 Multiple Comparisons Correction

For multiple comparisons (e.g., ablation study with 5 components):

**Bonferroni Correction**: α_corrected = α / n

- For 5 comparisons: α_corrected = 0.05 / 5 = 0.01

---

## 4. Effect Size

### 4.1 Cohen's d

Cohen's d measures standardized effect size:

```zig
pub fn cohensD(group1: []const f32, group2: []const f32) f32 {
    const mean1 = mean(group1);
    const mean2 = mean(group2);
    const var1 = variance(group1);
    const var2 = variance(group2);

    // Pooled standard deviation
    const sp = @sqrt((var1 + var2) / 2.0);

    return @abs(mean1 - mean2) / sp;
}
```

### 4.2 Effect Size Interpretation

| Cohen's d | Effect Size |
|-----------|-------------|
| 0.2 | Small |
| 0.5 | Medium |
| 0.8 | Large |
| 1.2 | Very Large |

### 4.3 Reporting Format

**Format**: `d = X.XX (small/medium/large/very large)`

**Example**: `d = 0.74 (large effect)`

---

## 5. Ablation Study Protocol

### 5.1 Baseline Comparison

Every ablation component must be compared against:
1. **Full model**: All components enabled
2. **Ablated model**: Single component removed
3. **Baseline model**: Only ablated component

### 5.2 Statistical Table Format

| Component | PPL | vs Full | ΔPPL | t-stat | p-value | Cohen's d |
|-----------|-----|---------|------|--------|---------|-----------|
| Full model | 124.1 ± 2.1 | baseline | — | — | — | — |
| w/o Sacred Attention | 138.5 ± 3.2 | -11.6% | +14.4 | t=2.31 | p=0.021* | d=0.74 (large) |
| w/o Consciousness | 131.2 ± 2.8 | -5.7% | +7.1 | t=1.98 | p=0.043* | d=0.52 (medium) |

---

## 6. Cross-Validation Protocol

### 6.1 K-Fold Cross-Validation

For small datasets, use k-fold cross-validation:

```zig
pub fn kFoldCrossValidation(
    data: []const Sample,
    k: usize,
    train_fn: fn ([]const Sample) Model,
    eval_fn: fn (Model, []const Sample) f32,
) []const f32 {
    const fold_size = data.len / k;
    var scores = std.ArrayList(f32).init(allocator);

    for (0..k) |fold| {
        const start = fold * fold_size;
        const end = if (fold == k - 1) data.len else (fold + 1) * fold_size;

        // Split data
        const test_data = data[start..end];
        const train_data = concatenate(data[0..start], data[end..]);

        // Train and evaluate
        const model = train_fn(train_data);
        const score = eval_fn(model, test_data);
        scores.append(score);
    }

    return scores.toOwnedSlice();
}
```

### 6.2 Stratified Sampling

For imbalanced datasets, use stratified k-fold:
- Each fold preserves class distribution
- Prevents bias in small classes

---

## 7. Bootstrap Validation

### 7.1 Non-Parametric Bootstrap

For metrics without known distribution:

```zig
pub fn bootstrapCI(values: []const f32, n_bootstrap: usize, confidence: f32) struct { lower: f32, upper: f32 } {
    var allocator = std.heap.page_allocator;
    var bootstrap_means = std.ArrayList(f32).init(allocator);
    defer bootstrap_means.deinit();

    const n = values.len;
    var prng = std.Random.DefaultPrng.init(42);

    for (0..n_bootstrap) |_| {
        var sum: f32 = 0;
        for (0..n) |_| {
            const idx = prng.random().uintLessThan(usize, n);
            sum += values[idx];
        }
        bootstrap_means.append(sum / @as(f32, @floatFromInt(n)));
    }

    // Sort and find percentiles
    std.sort.insertion(f32, bootstrap_means.items, {}, comptime std.sort.asc(f32));
    const lower_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(n_bootstrap)) * (1 - confidence) / 2));
    const upper_idx = @as(usize, @intFromFloat(@as(f64, @floatFromInt(n_bootstrap)) * (1 + confidence) / 2));

    return .{
        .lower = bootstrap_means.items[lower_idx],
        .upper = bootstrap_means.items[upper_idx],
    };
}
```

---

## 8. Power Analysis

### 8.1 Sample Size Calculation

For planning experiments:

```zig
pub fn requiredSampleSize(effect_size: f32, alpha: f32, power: f32) usize {
    // Simplified calculation for two-sample t-test
    const z_alpha = 1.96; // For alpha = 0.05
    const z_beta = 0.84; // For power = 0.80

    const n_per_group = @ceil(2 * @pow(z_alpha + z_beta, 2) / @pow(effect_size, 2));
    return @as(usize, @intFromFloat(n_per_group));
}
```

### 8.2 Power Analysis Guidelines

| Effect Size | Minimum n (per group) | Total n |
|-------------|----------------------|---------|
| Small (0.2) | 394 | 788 |
| Medium (0.5) | 64 | 128 |
| Large (0.8) | 26 | 52 |

---

## 9. Reporting Templates

### 9.1 Main Results Table

```
Table 1: Main Results on TinyStories

Method        | PPL (95% CI)      | Params (M) | Bits/param | Energy (kWh)
--------------|-------------------|------------|------------|-------------
HSLM (Ours)   | 124.1 ± 2.1       | 1.95       | 1.58       | 0.28
              | [122.0, 126.2]    |            |            |
BitNet b1.58  | 130.1 ± 2.3       | 1.95       | 1.58       | 0.45
              | [127.8, 132.4]    |            |            |
LUT-LLM       | 135.0 ± 3.1       | 1.95       | 4.00       | 0.52
              | [131.9, 138.1]    |            |            |
```

### 9.2 Ablation Study Table

```
Table 2: Ablation Study

Configuration  | PPL (95% CI)      | Δ vs Full | p-value | Cohen's d
----------------|-------------------|-----------|---------|----------
Full model      | 124.1 ± 2.1       | —         | —       | —
                | [122.0, 126.2]    |           |         |
w/o Sacred Attn | 138.5 ± 3.2       | +14.4     | 0.021*  | 0.74 (large)
                | [135.3, 141.7]    |           |         |
w/o Conscious   | 131.2 ± 2.8       | +7.1      | 0.043*  | 0.52 (medium)
                | [128.4, 134.0]    |           |         |
```

---

## 10. Statistical Validity Checklist

Before publication, verify:

- [ ] All experiments have minimum 10 runs
- [ ] All metrics report 95% confidence intervals
- [ ] All comparisons include p-values
- [ ] Effect sizes reported for significant results
- [ ] Multiple comparisons corrected (Bonferroni or FDR)
- [ ] Sample sizes justified by power analysis
- [ ] Outliers documented and justified
- [ ] Distribution assumptions tested (Shapiro-Wilk)
- [ ] Equal variance assumption tested (Levene's test)
- [ ] Non-parametric alternatives used when assumptions violated

---

## 11. Implementation

### 11.1 Zig Statistics Module

```zig
// src/hslm/statistics.zig
const std = @import("std");

pub const Statistics = struct {
    /// Calculate arithmetic mean
    pub fn mean(values: []const f32) f32 {
        var sum: f32 = 0;
        for (values) |v| sum += v;
        return sum / @as(f32, @floatFromInt(values.len));
    }

    /// Calculate sample standard deviation
    pub fn stdDev(values: []const f32) f32 {
        const m = mean(values);
        var sum_sq: f32 = 0;
        for (values) |v| {
            const diff = v - m;
            sum_sq += diff * diff;
        }
        return @sqrt(sum_sq / @as(f32, @floatFromInt(values.len - 1)));
    }

    /// 95% confidence interval
    pub fn confidenceInterval95(values: []const f32) struct { lower: f32, upper: f32 } {
        const n = @as(f32, @floatFromInt(values.len));
        const m = mean(values);
        const s = stdDev(values);
        const margin = 1.96 * s / @sqrt(n);
        return .{ .lower = m - margin, .upper = m + margin };
    }

    /// Two-sample t-test (independent samples)
    pub fn tTest(group1: []const f32, group2: []const f32) struct { p_value: f32, t_stat: f32 } {
        const n1 = @as(f32, @floatFromInt(group1.len));
        const n2 = @as(f32, @floatFromInt(group2.len));
        const m1 = mean(group1);
        const m2 = mean(group2);
        const v1 = variance(group1);
        const v2 = variance(group2);

        // Pooled variance
        const sp_sq = ((n1 - 1) * v1 + (n2 - 1) * v2) / (n1 + n2 - 2);
        const sp = @sqrt(sp_sq);

        // t-statistic
        const t_stat = (m1 - m2) / (sp * @sqrt(1/n1 + 1/n2));

        // Approximate p-value (two-tailed)
        const abs_t = if (t_stat < 0) -t_stat else t_stat;
        const p_value = if (abs_t > 2.58) 0.01 else if (abs_t > 1.96) 0.05 else 0.10;

        return .{ .p_value = p_value, .t_stat = t_stat };
    }

    /// Sample variance
    pub fn variance(values: []const f32) f32 {
        const m = mean(values);
        var sum_sq: f32 = 0;
        for (values) |v| {
            const diff = v - m;
            sum_sq += diff * diff;
        }
        return sum_sq / @as(f32, @floatFromInt(values.len - 1));
    }

    /// Cohen's d effect size
    pub fn cohensD(group1: []const f32, group2: []const f32) f32 {
        const m1 = mean(group1);
        const m2 = mean(group2);
        const v1 = variance(group1);
        const v2 = variance(group2);

        // Pooled standard deviation
        const sp = @sqrt((v1 + v2) / 2);

        return @abs(m1 - m2) / sp;
    }
};
```

---

## 12. Experimental Logging

### 12.1 Experiment Metadata

Every experimental run must log:

```json
{
  "experiment_id": "exp_001",
  "timestamp": "2026-03-26T14:30:00Z",
  "seed": 42,
  "configuration": {
    "model": "HSLM",
    "dataset": "TinyStories",
    "vocab_size": 729,
    "hidden_dim": 729,
    "num_blocks": 3,
    "learning_rate": 0.001,
    "batch_size": 64,
    "total_steps": 30000
  },
  "results": {
    "final_ppl": 124.1,
    "final_loss": 1.94,
    "training_time_hours": 6.0,
    "energy_kwh": 0.28
  },
  "checkpoint_metrics": [
    {"step": 5000, "ppl": 142.5, "loss": 3.12},
    {"step": 10000, "ppl": 128.7, "loss": 2.45},
    {"step": 15000, "ppl": 125.1, "loss": 2.18},
    {"step": 20000, "ppl": 124.8, "loss": 2.05},
    {"step": 25000, "ppl": 124.3, "loss": 1.98},
    {"step": 30000, "ppl": 124.1, "loss": 1.94}
  ]
}
```

---

## 13. Reproducibility Requirements

### 13.1 Complete Reproducibility Package

Each publication must include:

1. **Code**: Complete source code with version control
2. **Data**: Dataset download scripts and checksums
3. **Configurations**: Exact hyperparameters in machine-readable format
4. **Environment**: Docker container or conda environment file
5. **Results**: Raw experimental logs and processed results
6. **Documentation**: Step-by-step reproduction guide

### 13.2 Reproducibility Checklist

- [ ] Code compiles without errors
- [ ] All dependencies specified with versions
- [ ] Random seeds documented
- [ ] Hardware platform specified
- [ ] Runtime estimates provided
- [ ] Intermediate checkpoints saved
- [ ] Results within 5% variance when reproduced

---

**φ² + 1/φ² = 3 | TRINITY**

---

**Document Control:** STAT-VALIDATION-001
**Status:** Active — All experiments must follow this framework
