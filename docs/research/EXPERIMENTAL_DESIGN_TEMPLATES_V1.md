# Experimental Design Templates — Trinity S³AI Research

**Version:** 1.0.0
**Date:** 2026-03-26
**Purpose:** Reproducible experimental templates with statistical validation
**Related:** docs/research/CODEBASE_LITERATURE_SYNTHESIS_V1.md, src/hslm/statistics.zig

---

## Part I: Experiment Template Structure

### 1.1 Standard Experiment Format

Every experiment should document:

```yaml
experiment_name: "sacred_vs_standard_scaling"
date: "2026-03-26"
researcher: "Dmitrii Vasilev"
hypothesis: "Sacred scaling improves convergence speed by 3.2×"

# Configuration
model:
  vocab_size: 729
  embed_dim: 243
  hidden_dim: 729
  num_blocks: 3
  num_heads: 3
  context_len: 81

training:
  dataset: "TinyStories"
  optimizer: "LAMB"
  learning_rate: 0.001
  lr_schedule: "cosine"
  warmup_steps: 2000
  total_steps: 30000
  batch_size: 64
  gradient_accumulation: 2

# Variables
independent_variable:
  name: "attention_scaling"
  levels:
    - "standard"  # 1/√d
    - "sacred"    # 1/d^φ⁻³
    - "adaptive"  # sacred→standard via cosine

dependent_variables:
  - name: "perplexity"
    unit: "PPL"
    lower_is_better: true
  - name: "convergence_steps"
    unit: "steps"
    lower_is_better: true
  - name: "training_stability"
    unit: "loss variance"
    lower_is_better: true

# Statistical design
seeds: [42, 43, 44, 45, 46, 47, 48, 49, 50, 51]  # 10 seeds
alpha: 0.05  # Significance level
power: 0.80  # Statistical power
effect_size: "medium"  # Cohen's d ≈ 0.5

# Analysis plan
statistical_tests:
  - "t_test"  # Compare sacred vs standard
  - "wilcoxon"  # Non-parametric alternative
  - "cohens_d"  # Effect size
  - "bootstrap_ci"  # 95% confidence intervals

# Reporting
results_format: "mean ± 95% CI (n=10)"
figures:
  - "training_curves_with_ci.png"
  - "final_ppl_boxplot.png"
  - "convergence_speed_comparison.png"
```

---

## Part II: Scaling Factor Experiment

### 2.1 Experimental Design

**Title:** Sacred vs Standard vs Adaptive Scaling Factor

**Hypothesis:** H₁: Sacred scaling (1/d^φ⁻³) achieves lower perplexity and faster convergence than standard scaling (1/√d).

**Design:** Randomized complete block design

| Config | Scale Formula | Transition |
|--------|---------------|-------------|
| C1 | 1/√d (standard) | None |
| C2 | 1/d^φ⁻³ (sacred) | None |
| C3 | 1/d^φ⁻³ → 1/√d | Linear @ 50% |
| C4 | 1/d^φ⁻³ → 1/√d | Cosine @ 50% |
| C5 | 1/d^φ⁻³ → 1/√d | Exponential @ 50% |

**Replication:** 10 seeds per config (50 total runs)

**Metrics:**

| Metric | Type | Unit | Target |
|--------|------|------|--------|
| Final PPL | Primary | PPL | Minimize |
| Convergence @125 | Secondary | Steps | Minimize |
| Training Loss Variance | Stability | σ² | Minimize |
| GPU Memory | Resource | MB | <4000 |
| Throughput | Performance | tok/s | Maximize |

### 2.2 Expected Results Table

| Config | PPL (mean±95%CI) | Convergence | Stability | Recommendation |
|--------|-------------------|-------------|------------|----------------|
| C1 | 130.5 ± 3.0 | 28K steps | ±3.2 | Baseline |
| C2 | 124.1 ± 2.1 | 18K steps | ±2.8 | Strong early |
| C3 | 122.8 ± 1.9 | 20K steps | ±2.5 | Good balance |
| **C4** | **121.5 ± 1.5** | **15K steps** | **±2.2** | **Recommended** |
| C5 | 123.2 ± 2.3 | 17K steps | ±2.6 | Good alternative |

### 2.3 Statistical Analysis Plan

```python
#!/usr/bin/env python3
"""
Statistical analysis for scaling factor experiment
"""

import numpy as np
import pandas as pd
from scipy import stats
from typing import List, Tuple

def load_results(configs: List[str]) -> dict:
    """Load experimental results from JSONL logs."""
    results = {}
    for config in configs:
        ppl_values = []
        convergence_steps = []
        for seed in range(42, 52):
            # Load from training log
            log_file = f"data/experiments/{config}/seed_{seed}/metrics.jsonl"
            with open(log_file) as f:
                for line in f:
                    data = json.loads(line)
                    if data["step"] == 30000:
                        ppl_values.append(data["perplexity"])
                    if data["perplexity"] <= 125:
                        convergence_steps.append(data["step"])
                        break
        results[config] = {
            "ppl": ppl_values,
            "convergence": convergence_steps
        }
    return results

def analyze_ppl(results: dict) -> pd.DataFrame:
    """Compute PPL statistics with 95% CI."""
    rows = []
    for config, data in results.items():
        ppl = data["ppl"]
        mean = np.mean(ppl)
        std = np.std(ppl)
        sem = std / np.sqrt(len(ppl))
        ci = 1.96 * sem  # 95% CI
        rows.append({
            "config": config,
            "mean": mean,
            "std": std,
            "sem": sem,
            "ci_lower": mean - ci,
            "ci_upper": mean + ci,
            "n": len(ppl)
        })
    return pd.DataFrame(rows)

def t_test_paired(results: dict, config1: str, config2: str) -> dict:
    """Paired t-test (same seeds) between two configs."""
    ppl1 = results[config1]["ppl"]
    ppl2 = results[config2]["ppl"]

    # Paired t-test
    t_stat, p_value = stats.ttest_rel(ppl1, ppl2)

    # Cohen's d (paired)
    diffs = np.array(ppl1) - np.array(ppl2)
    d = np.mean(diffs) / np.std(diffs, ddof=1)

    # Effect size interpretation
    if abs(d) < 0.2:
        effect = "negligible"
    elif abs(d) < 0.5:
        effect = "small"
    elif abs(d) < 0.8:
        effect = "medium"
    else:
        effect = "large"

    return {
        "t_statistic": t_stat,
        "p_value": p_value,
        "cohens_d": d,
        "effect_size": effect,
        "significant": p_value < 0.05
    }

def bootstrap_ci(values: List[float], n_bootstrap: int = 10000, ci: float = 0.95) -> Tuple[float, float, float]:
    """Bootstrap confidence interval."""
    boot_means = []
    for _ in range(n_bootstrap):
        sample = np.random.choice(values, size=len(values), replace=True)
        boot_means.append(np.mean(sample))

    alpha = (1 - ci) / 2
    lower = np.percentile(boot_means, 100 * alpha)
    upper = np.percentile(boot_means, 100 * (1 - alpha))
    return np.mean(values), lower, upper

# Main analysis
if __name__ == "__main__":
    configs = ["C1", "C2", "C3", "C4", "C5"]
    results = load_results(configs)

    # PPL table
    ppl_df = analyze_ppl(results)
    print("## Perplexity Results (mean ± 95% CI)")
    print(ppl_df.to_string(index=False))

    # Pairwise comparisons vs baseline (C1)
    print("\n## Pairwise Comparisons vs Baseline (C1)")
    for config in configs[1:]:
        comp = t_test_paired(results, "C1", config)
        sig = "***" if comp["p_value"] < 0.001 else "**" if comp["p_value"] < 0.01 else "*" if comp["p_value"] < 0.05 else ""
        print(f"C1 vs {config}: t={comp['t_statistic']:.3f}, p={comp['p_value']:.4f}, d={comp['cohens_d']:.3f} ({comp['effect_size']}) {sig}")
```

---

## Part III: Training Log Format

### 3.1 JSONL Schema

Each training run produces a JSONL file with per-step metrics:

```jsonl
{"step": 0, "epoch": 0, "timestamp": "2026-03-26T10:00:00Z", "seed": 42, "config": "C4", "loss_train": 10.523, "loss_val": 10.487, "perplexity": 36123.4, "learning_rate": 0.001, "gradient_norm": 12.345, "throughput_tok_s": 4523.1, "scale_current": 0.354, "progress": 0.0}
{"step": 100, "epoch": 0, "timestamp": "2026-03-26T10:01:23Z", "seed": 42, "config": "C4", "loss_train": 8.234, "loss_val": 8.156, "perplexity": 3492.1, "learning_rate": 0.00108, "gradient_norm": 10.123, "throughput_tok_s": 4518.7, "scale_current": 0.353, "progress": 0.003}
{"step": 30000, "epoch": 1, "timestamp": "2026-03-26T15:23:45Z", "seed": 42, "config": "C4", "loss_train": 4.823, "loss_val": 4.793, "perplexity": 121.5, "learning_rate": 0.0001, "gradient_norm": 2.345, "throughput_tok_s": 4498.2, "scale_current": 0.111, "progress": 1.0}
```

### 3.2 Final Results Schema

At the end of training, produce a summary JSON:

```json
{
  "experiment_id": "sacred_vs_standard_20260326",
  "config": "C4",
  "seed": 42,
  "model": {
    "vocab_size": 729,
    "embed_dim": 243,
    "hidden_dim": 729,
    "num_blocks": 3,
    "num_heads": 3,
    "context_len": 81
  },
  "training": {
    "total_steps": 30000,
    "optimizer": "LAMB",
    "learning_rate": 0.001,
    "lr_schedule": "cosine",
    "warmup_steps": 2000
  },
  "results": {
    "final_perplexity": 121.5,
    "convergence_step": 14500,
    "convergence_perplexity": 125.0,
    "best_perplexity": 119.8,
    "best_step": 28500
  },
  "stability": {
    "loss_variance": 2.3,
    "perplexity_std": 5.2,
    "gradient_norm_mean": 3.4,
    "gradient_norm_std": 1.2
  },
  "resources": {
    "gpu_memory_mb": 3850,
    "throughput_tok_s": 4498.2,
    "training_time_minutes": 47.3
  },
  "scaling": {
    "initial_scale": 0.354,
    "final_scale": 0.111,
    "transition_type": "cosine",
    "transition_start": 0.5
  }
}
```

---

## Part IV: Reproducibility Checklist

### 4.1 Before Submission

For each experiment, verify:

- [ ] **Code Version:** Git commit hash recorded
- [ ] **Dependencies:** Zig version, Python version, CUDA version (if applicable)
- [ ] **Hardware:** CPU, GPU, RAM specifications
- [ ] **Dataset:** Checksum, download URL, preprocessing steps
- [ ] **Random Seeds:** All seeds documented
- [ ] **Hyperparameters:** All values listed (including defaults)
- [ ] **Metrics:** Definition and computation method
- [ ] **Statistical Tests:** Test name, α level, effect size
- [ ] **Code Availability:** Public repository with tag/release
- [ ] **Data Availability:** Download link or generation script

### 4.2 Zenodo Upload Checklist

For each Zenodo bundle, include:

- [ ] **Description:** Enhanced markdown with 5-sentence abstract
- [ ] **Figures:** 6 publication-quality figures (PNG/SVG)
- [ ] **Tables:** 4 LaTeX tables with statistical formatting
- [ ] **Data:** CSV files with all experimental results
- [ ] **Notebooks:** Jupyter notebooks for analysis
- [ ] **Code:** Minimal reproducible example
- [ ] **Dockerfile:** Complete environment specification
- [ ] **README:** Step-by-step reproduction guide
- [ ] **CITATION.cff:** Standard citation format
- [ ] **LICENSE:** MIT (or other OSI-approved)

---

## Part V: Statistical Power Analysis

### 5.1 Sample Size Calculator

For detecting a difference Δ in perplexity between two configs:

```python
import numpy as np
from scipy import stats
import matplotlib.pyplot as plt

def required_sample_size(effect_size: float, alpha: float = 0.05, power: float = 0.80) -> int:
    """
    Calculate required sample size per group for two-sample t-test.

    Args:
        effect_size: Cohen's d (0.2=small, 0.5=medium, 0.8=large)
        alpha: Significance level (Type I error rate)
        power: Statistical power (1 - Type II error rate)

    Returns:
        Required sample size per group
    """
    # Approximation formula (Cohen, 1988)
    z_alpha = stats.norm.ppf(1 - alpha/2)
    z_beta = stats.norm.ppf(power)

    n_per_group = 2 + ((z_alpha + z_beta) / effect_size) ** 2

    return int(np.ceil(n_per_group))

# Example: Detecting 5 PPL difference with σ=2.1
mean_std = 130.5
mean_sacred = 124.1
pooled_std = 2.5  # Estimated from pilot data
effect_size = (mean_std - mean_sacred) / pooled_std  # d ≈ 2.56

n = required_sample_size(effect_size)
print(f"Required sample size: {n} per group (total: {2*n})")

# Power curve
sample_sizes = range(5, 51)
powers = []
for n in sample_sizes:
    # Compute power for given n
    se = pooled_std * np.sqrt(2/n)
    t_crit = stats.t.ppf(1 - 0.05/2, df=2*n-2)
    non_cent = (mean_std - mean_sacred) / se
    power = 1 - stats.nct.cdf(t_crit, df=2*n-2, nc=non_cent)
    powers.append(power)

plt.figure(figsize=(8, 5))
plt.plot(sample_sizes, powers, marker='o')
plt.axhline(y=0.80, color='r', linestyle='--', label='80% power')
plt.xlabel('Sample Size per Group')
plt.ylabel('Statistical Power')
plt.title('Power Curve for Sacred vs Standard Scaling')
plt.grid(True, alpha=0.3)
plt.legend()
plt.savefig('figures/power_curve.png', dpi=300)
```

### 5.2 Effect Size Benchmarks

| Effect Size | Cohen's d | Interpretation | Example Context |
|-------------|-----------|----------------|-----------------|
| Trivial | <0.1 | Negligible | <1% PPL difference |
| Small | 0.2 | Noticeable | 2-3% PPL difference |
| Medium | 0.5 | Practical | 5% PPL difference |
| Large | 0.8 | Substantial | 10% PPL difference |
| Huge | >1.2 | Outstanding | >15% PPL difference |

**Sacred vs Standard Expected:** d ≈ 2.5 (Huge effect)

---

## Part VI: Figure Templates

### 6.1 Training Curves with Confidence Intervals

```python
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns

def plot_training_curves_with_ci(data: dict, output_path: str):
    """
    Plot training curves with 95% confidence intervals.

    Args:
        data: Dict with keys 'steps', 'mean_loss', 'ci_lower', 'ci_upper'
        output_path: Path to save figure
    """
    plt.style.use('seaborn-v0_8-whitegrid')

    fig, ax = plt.subplots(figsize=(10, 6))

    # Plot mean loss
    ax.plot(data['steps'], data['mean_loss'], linewidth=2, label='Mean Loss')

    # Shade confidence interval
    ax.fill_between(
        data['steps'],
        data['ci_lower'],
        data['ci_upper'],
        alpha=0.3,
        label='95% CI'
    )

    # Formatting
    ax.set_xlabel('Training Steps', fontsize=12)
    ax.set_ylabel('Loss', fontsize=12)
    ax.set_title('Training Loss with 95% Confidence Intervals (n=10)', fontsize=14)
    ax.legend(fontsize=10)
    ax.grid(True, alpha=0.3)

    # Log scale for better visualization
    ax.set_yscale('log')

    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    plt.close()
```

### 6.2 Box Plot Comparison

```python
def plot_boxplot_comparison(data: dict, output_path: str):
    """
    Plot box plots comparing final perplexity across configs.
    """
    fig, ax = plt.subplots(figsize=(10, 6))

    # Prepare data
    configs = list(data.keys())
    ppl_data = [data[c]['ppl'] for c in configs]

    # Create box plot
    bp = ax.boxplot(ppl_data, labels=configs, patch_artist=True)

    # Color boxes
    colors = ['#66c2a5', '#fc8d62', '#8da0cb', '#e78ac3', '#a6d854']
    for patch, color in zip(bp['boxes'], colors):
        patch.set_facecolor(color)
        patch.set_alpha(0.7)

    # Add individual points
    for i, (config, values) in enumerate(zip(configs, ppl_data), 1):
        x = np.random.normal(i, 0.04, size=len(values))
        ax.plot(x, values, 'r.', alpha=0.5)

    ax.set_ylabel('Final Perplexity', fontsize=12)
    ax.set_xlabel('Configuration', fontsize=12)
    ax.set_title('Final Perplexity Distribution (n=10 per config)', fontsize=14)
    ax.grid(True, alpha=0.3, axis='y')

    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    plt.close()
```

---

## Part VII: Common Analysis Scripts

### 7.1 Extract Training Metrics

```bash
#!/bin/bash
# extract_metrics.sh - Extract key metrics from JSONL logs

INPUT_DIR="data/experiments"
OUTPUT_FILE="results_summary.csv"

echo "config,seed,final_ppl,convergence_step,best_ppl,training_time_min" > $OUTPUT_FILE

for config_dir in $INPUT_DIR/*/; do
    config=$(basename $config_dir)
    for seed_dir in $config_dir/seed_*/; do
        seed=$(basename $seed_dir)
        log_file="$seed_dir/metrics.jsonl"

        if [ -f "$log_file" ]; then
            # Extract final perplexity
            final_ppl=$(jq -r 'select(.step == 30000) | .perplexity' $log_file)

            # Extract convergence step (first PPL ≤ 125)
            conv_step=$(jq -r 'select(.perplexity <= 125) | .step // empty' $log_file | head -1)

            # Extract best perplexity
            best_ppl=$(jq -r '[.perplexity] | min' $log_file)

            # Extract training time
            train_time=$(jq -r '[.timestamp] | .[-1]' $log_file)

            echo "$config,$seed,$final_ppl,$conv_step,$best_ppl,0" >> $OUTPUT_FILE
        fi
    done
done
```

### 7.2 Generate LaTeX Table

```python
#!/usr/bin/env python3
"""
Generate LaTeX table from experimental results.
"""

def generate_latex_table(results_df: pd.DataFrame, caption: str, label: str) -> str:
    """Generate LaTeX table from results DataFrame."""

    latex = "\\begin{table}[t]\n"
    latex += f"\\caption{{{caption}}}\n"
    latex += f"\\label{{{label}}}\n"
    latex += "\\centering\n"
    latex += "\\begin{tabular}{lcccc}\n"
    latex += "\\toprule\n"
    latex += "Config & PPL & 95\\% CI & Convergence & Stability \\\\\n"
    latex += "\\midrule\n"

    for _, row in results_df.iterrows():
        config = row['config']
        mean = row['mean']
        ci_lower = row['ci_lower']
        ci_upper = row['ci_upper']
        convergence = row['convergence_mean']
        stability = row['stability_std']

        latex += f"{config} & {mean:.1f} & [{ci_lower:.1f}, {ci_upper:.1f}] & {convergence:.0f}K & ±{stability:.2f} \\\\\n"

    latex += "\\bottomrule\n"
    latex += "\\end{tabular}\n"
    latex += "\\end{table}\n"

    return latex

# Usage
results_df = pd.read_csv("results_summary.csv")
latex_table = generate_latex_table(
    results_df,
    caption="Scaling factor comparison on TinyStories (n=10)",
    label="tab:scaling_comparison"
)
print(latex_table)
```

---

## Conclusion

This document provides:

1. **Standard experiment format** (YAML template)
2. **Statistical analysis plan** (Python scripts)
3. **Training log schema** (JSONL + summary JSON)
4. **Reproducibility checklists** (pre-submission + Zenodo)
5. **Power analysis tools** (sample size calculator)
6. **Figure templates** (training curves, box plots)
7. **Common scripts** (metrics extraction, LaTeX generation)

**Next Steps:**
1. Set up experiment infrastructure
2. Run 10-seed ablation studies
3. Generate publication-quality figures
4. Update Zenodo bundles with results

---

**Document Control:** EXP-DESIGN-001
**Status:** Active — Experimental design templates
**Related:** #415, src/hslm/statistics.zig
**φ² + 1/φ² = 3 | TRINITY**
