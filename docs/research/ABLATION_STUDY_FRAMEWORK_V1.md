# Ablation Study Framework — V1.0

**Version:** 1.0.0
**Date:** 2026-03-26
**Author:** Dmitrii Vasilev
**Purpose:** Systematic ablation study framework for Trinity S³AI research

---

## Abstract

This document describes the systematic ablation study framework implemented for Trinity S³AI. Ablation studies are critical for understanding the contribution of individual components to overall system performance. Following NeurIPS 2025/2026 best practices, this framework enables:

1. **Component Toggling** — Individual enable/disable of Trinity features
2. **Statistical Rigor** — Multiple seeds with confidence intervals
3. **Publication-Ready Output** — CSV + LaTeX table generation
4. **Reproducibility** — Deterministic experiments with seeded RNG

---

## Part I: Component Toggles

### 1.1 Ablatable Components

| Component | Description | Expected Impact |
|-----------|-------------|-----------------|
| Sacred Scaling | d^(-φ⁻³) gradient preservation | 4× improvement in gradients |
| Ternary Encoding | Balanced ternary {-1, 0, +1} | 1.585 bits/trit density |
| VSA Operations | Hypervector bind/unbind/bundle | Johnson-Lindenstrauss capacity |
| SEVO Optimization | φ-based hyperparameter search | Faster convergence |
| Temple (TTT) | Sacred math + TRI-27 core | Type safety + correctness |
| TRI-27 Architecture | 27-register set, Coptic mapping | Hardware efficiency |
| HSLM Training | Hierarchical sparse language model | 125.3 PPL on TinyStories |
| Phoenix Autophagy | Sleep-wake regeneration cycles | Long-term stability |
| Queen Orchestration | S³AI brain (4 regions + 6 PFC) | Agent coordination |

### 1.2 Configuration Examples

**Baseline (no Trinity features):**
```
components: [baseline_only]
```

**Sacred Scaling Only:**
```
components: [baseline_only, enable_sacred_scaling]
```

**Ternary Encoding Only:**
```
components: [baseline_only, enable_ternary_encoding]
```

**VSA Only:**
```
components: [baseline_only, enable_vsa]
```

**Full Trinity System:**
```
components: [full_system]
```

---

## Part II: Statistical Methods

### 2.1 Metrics Collected

| Metric | Formula | Purpose |
|--------|---------|---------|
| Perplexity | exp(cross_entropy) | Language model quality |
| Loss | Cross-entropy | Training objective |
| Convergence Steps | epochs to target | Training efficiency |
| Tokens/Second | throughput | Performance |
| Energy/Token | joules / tokens | Efficiency |
| Memory Usage | MB | Resource consumption |
| L1 Distance | Σ\|a-b\| | Vector similarity |
| Cosine Similarity | (a·b)/(\|a\|\|b\|) | Angle similarity |
| Capacity Bound | n ≤ exp(ε²d/2) | VSA theoretical limit |
| Gradient Scale | \|\∇L\| / \|\∇L_std\| | Gradient preservation |

### 2.2 Statistical Tests

**Confidence Intervals (95%):**
```
CI = μ ± z × (σ / √n)
where:
  μ = sample mean
  σ = sample standard deviation
  z = 1.96 (n ≥ 30), 2.262 (n ≥ 10), 2.776 (n < 10)
  n = number of seeds
```

**Paired t-test (p-value):**
```
t = μ_diff / (σ_diff / √n)
where:
  μ_diff = mean of differences
  σ_diff = std of differences
```

**Cohen's d (effect size):**
```
d = (μ_a - μ_b) / σ_pooled
where:
  σ_pooled = √[((n_a-1)σ_a² + (n_b-1)σ_b²) / (n_a + n_b - 2)]

Interpretation:
  |d| < 0.2: Small effect
  |d| < 0.5: Medium effect
  |d| < 0.8: Large effect
  |d| ≥ 0.8: Very large effect
```

---

## Part III: Experimental Protocol

### 3.1 Standard Configuration

```zig
const AblationConfig = struct {
    name: []const u8,           // "baseline", "sacred_scaling_only", etc.
    components: []const ComponentToggle,
    seeds: []const u32,         // [42, 123, 456, 789, 101112] (5 seeds)
    dataset: Dataset,            // .tinystories
    epochs: usize,                // 30000
    batch_size: usize,            // 32
    learning_rate: f64,           // 3e-4
    metrics: []const Metric,
    output_path: []const u8,
};
```

### 3.2 Recommended Seeds

**For statistical significance (p < 0.05):**
- Minimum: 3 seeds (quick validation)
- Standard: 5 seeds (good balance)
- Rigorous: 10 seeds (publication-ready)

**Example seed set:**
```
[42, 123, 456, 789, 101112]
```

### 3.3 Execution Protocol

1. **Preparation:**
   - Set random seed
   - Apply component toggles
   - Initialize model

2. **Training:**
   - Train for specified epochs
   - Log metrics every 100 steps
   - Checkpoint at convergence

3. **Evaluation:**
   - Compute final perplexity
   - Measure tokens/second
   - Record energy consumption

4. **Aggregation:**
   - Compute mean ± std across seeds
   - Calculate 95% confidence intervals
   - Run paired t-tests vs baseline
   - Compute Cohen's d effect sizes

---

## Part IV: Output Formats

### 4.1 CSV Format

**Header:**
```csv
config,n_seeds,train_mean,train_std,train_ci_low,train_ci_high,val_mean,val_std,test_mean,ppl_mean,ppl_std,p_value,cohen_d
```

**Example Row:**
```csv
sacred_scaling_only,5,1.234,0.045,1.190,1.278,1.456,0.056,1.389,115.3,4.2,0.001,1.89
```

### 4.2 LaTeX Table Format

```latex
\begin{table}[t]
  \centering
  \caption{Ablation Study Results}
  \label{tab:ablation}
  \begin{tabular}{lcccc}
    \toprule
    Configuration & Train Loss & Val Loss & Test Loss & PPL & Effect Size \\
    \midrule
    Baseline & 1.567 $\pm$ 0.089 & 1.623 $\pm$ 0.092 & 1.589 $\pm$ 0.087 & 138.2 & - \\
    Sacred Scaling & 1.234 $\pm$ 0.045 & 1.456 $\pm$ 0.056 & 1.389 $\pm$ 0.051 & 115.3 & 1.89 \\
    Ternary Only & 1.412 $\pm$ 0.067 & 1.534 $\pm$ 0.071 & 1.478 $\pm$ 0.068 & 128.7 & 0.95 \\
    VSA Only & 1.389 $\pm$ 0.054 & 1.501 $\pm$ 0.062 & 1.456 $\pm$ 0.058 & 122.1 & 1.23 \\
    Full System & 1.102 $\pm$ 0.032 & 1.234 $\pm$ 0.038 & 1.198 $\pm$ 0.035 & 105.7 & 2.45 \\
    \bottomrule
  \end{tabular}
\end{table}
```

---

## Part V: Expected Results

### 5.1 Hypothesized Ablation Results

| Configuration | Expected PPL | Expected Improvement |
|---------------|--------------|---------------------|
| Baseline | 138.2 ± 5.2 | - |
| Sacred Scaling Only | 115.3 ± 4.2 | 16.6% ↓ |
| Ternary Only | 128.7 ± 4.8 | 6.9% ↓ |
| VSA Only | 122.1 ± 4.5 | 11.6% ↓ |
| Full System | 105.7 ± 3.8 | 23.5% ↓ |

### 5.2 Effect Size Interpretation

| Comparison | Expected Cohen's d | Interpretation |
|------------|-------------------|----------------|
| Sacred vs Baseline | 1.89 | Very large effect |
| Ternary vs Baseline | 0.95 | Large effect |
| VSA vs Baseline | 1.23 | Very large effect |
| Full vs Baseline | 2.45 | Very large effect |
| Full vs Sacred | 0.56 | Medium effect |

---

## Part VI: Usage Examples

### 6.1 Command-Line Interface

```bash
# Run single ablation configuration
tri ablation run \
  --config configs/ablation/sacred_scaling.json \
  --seeds 42,123,456,789,101112 \
  --output results/ablation/sacred_scaling.csv

# Run all ablation configurations
tri ablation run-all \
  --seeds 42,123,456,789,101112 \
  --output results/ablation/

# Generate LaTeX table
tri ablation latex \
  --input results/ablation/ \
  --output figures/tables/ablation.tex
```

### 6.2 Programmatic API

```zig
const std = @import("std");
const AblationFramework = @import("ablation_framework.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const framework = AblationFramework.Framework.init(allocator);

    // Define seeds
    const seeds = [_]u32{ 42, 123, 456, 789, 101112 };

    // Get all standard configs
    const configs = try AblationFramework.standardConfigs.allConfigs(allocator, &seeds);
    defer {
        for (configs) |c| {
            allocator.free(c.components);
            allocator.free(c.metrics);
        }
        allocator.free(configs);
    }

    // Run studies
    var results = std.ArrayList(AblationFramework.AggregatedResult).init(allocator);
    defer {
        for (results.items) |*r| {
            allocator.free(r.config.components);
            allocator.free(r.config.metrics);
        }
        results.deinit();
    }

    for (configs) |config| {
        const result = try framework.runStudy(config);
        try results.append(result);
    }

    // Export to CSV
    try framework.exportCsv(results.items, "results/ablation/study.csv");

    // Generate LaTeX table
    const latex = try framework.generateLatexTable(results.items);
    defer allocator.free(latex);

    const latex_file = try std.fs.cwd().createFile("figures/tables/ablation.tex", .{});
    defer latex_file.close();
    try latex_file.writeAll(latex);
}
```

---

## Part VII: Integration with Training Pipeline

### 7.1 Component Toggle Application

When `enable_sacred_scaling` is active:
```zig
const sacred_scale = std.math.pow(@as(f64, @floatFromInt(dimension)), -0.236);
// vs standard: 1.0 / @sqrt(@as(f64, @floatFromInt(dimension)))
```

When `enable_ternary_encoding` is active:
```zig
const encoded = try encodeTrit27(value);  // {-1, 0, +1}
// vs standard: encodeFloat32(value)
```

When `enable_vsa` is active:
```zig
const hypervector = try generateHypervector(allocator, dimension);
const bound = try bind(allocator, &hypervector, &query);
```

### 7.2 Metric Collection

```zig
// During training
if (config.metrics.contains(.perplexity)) {
    const ppl = std.math.exp(cross_entropy);
    try metrics.append("perplexity", ppl);
}

if (config.metrics.contains(.gradient_scale)) {
    const scale = gradient_norm / baseline_gradient_norm;
    try metrics.append("gradient_scale", scale);
}
```

---

## Part VIII: Validation Checklist

### 8.1 Before Running Ablation Study

- [ ] Seeds defined (minimum 3, standard 5)
- [ ] Components toggled correctly
- [ ] Output directory exists
- [ ] Dataset available
- [ ] Baseline configuration prepared
- [ ] Metrics selected
- [ ] Statistical test parameters confirmed

### 8.2 During Ablation Study

- [ ] Each seed completes successfully
- [ ] Checkpoints saved
- [ ] Metrics logged at each step
- [ ] No warnings or errors
- [ ] Memory usage within limits

### 8.3 After Ablation Study

- [ ] All seeds completed
- [ ] CSV file generated
- [ ] LaTeX table generated
- [ ] Statistical tests passed
- [ ] Effect sizes computed
- [ ] Results reproducible (re-run)

---

## Part IX: Publication Guidelines

### 9.1 NeurIPS 2025/2026 Requirements

**Required Ablation Elements:**
1. Baseline comparison (no features)
2. Individual component contributions
3. Full system results
4. Statistical significance (p < 0.05)
5. Effect sizes (Cohen's d)
6. Confidence intervals (95%)
7. Multiple random seeds (≥3)

**Table Format:**
```
Table 2: Ablation Study Results
- Columns: Configuration, Metric 1 ± std, ..., p-value, Cohen's d
- Rows: Baseline, Component 1 only, Component 2 only, ..., Full system
```

**Caption Example:**
```
Table 2: Ablation study results on TinyStories validation set.
We systematically disable each component to measure its contribution.
All experiments use 5 random seeds; results show mean ± std.
Full system achieves 23.5% improvement over baseline (p < 0.001, Cohen's d = 2.45).
```

### 9.2 ICLR 2025 Requirements

**Additional Elements:**
- Broader impact statement
- Computational cost (FLOPs)
- Energy consumption (Joules)
- Comparison with 5+ baselines

---

## Part X: Future Enhancements

### 10.1 Planned Features

**Phase 2 (Q2 2026):**
1. Multi-dataset ablation (TinyStories, WikText, custom)
2. Hyperparameter sensitivity analysis
3. Ablation heatmaps
4. Interactive visualization

**Phase 3 (Q3 2026):**
1. Distributed ablation (parallel execution)
2. Automated analysis (recommend optimal config)
3. Integration with benchmark suite
4. Real-time monitoring

### 10.2 Integration Points

**With HSLM Training:**
- Hook into training loop
- Collect metrics per epoch
- Export to ablation format

**With Benchmark Suite:**
- Compare ablation results with baselines
- Generate unified results table

**With Profiling:**
- Add energy metrics
- Add FLOPs counting
- Add memory profiling

---

## Conclusion

The ablation study framework provides:

1. **Systematic Component Analysis** — 9 toggleable components
2. **Statistical Rigor** — Multiple seeds, CI, p-values, effect sizes
3. **Publication-Ready Output** — CSV + LaTeX formats
4. **Reproducibility** — Seeded experiments, deterministic results
5. **Extensibility** — Easy to add new components and metrics

**By using this framework, Trinity S³AI publications will:**
- Meet NeurIPS 2025/2026 ablation requirements
- Provide rigorous statistical validation
- Enable fair comparison with baselines
- Support reproducibility and transparency

---

**φ² + 1/φ² = 3 | TRINITY**

**Version:** 1.0.0 | **Date:** 2026-03-26 | **Author:** Dmitrii Vasilev
