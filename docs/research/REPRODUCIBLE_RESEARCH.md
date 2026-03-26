# Reproducible Research Guide — Trinity S³AI Framework

**Date**: 2026-03-26
**Version**: 1.0
**Author**: Dmitrii Vasilev

---

## Overview

This guide provides **scientifically rigorous** practices for reproducible research using the Trinity S³AI autonomous agent swarm framework, following NSF-recommended standards and the Open Science Framework.

---

## Part 1: Experimental Design

### 1.1 Preregistration

**Purpose**: Prevent p-hacking and HARKing (Hypothesizing After Results are Known)

**Template**:
```markdown
## Preregistration: [Experiment Name]

**Hypothesis**: H1: [Specific prediction]
**Null Hypothesis**: H0: [Specific prediction of no effect]

**Primary Endpoint**: [Metric to be used]
**Secondary Endpoints**: [Additional metrics]

**Sample Size**: Justification via power analysis
**Alpha**: 0.05 (two-tailed)
**Power**: 0.80

**Analysis Plan**:
- Primary analysis: [Method]
- Multiple testing correction: [Method]
- Outlier handling: [Criteria]

**Data Availability**: [Yes/No with explanation]
```

---

### 1.2 Randomization

**Why**: Eliminates selection bias and confounding

**Implementation**:
```python
import random
import hashlib

def seeded_random(seed: str, n: int) -> list[int]:
    """
    Generate reproducible random sequence from seed string.
    """
    # Hash seed to integer
    seed_hash = int(hashlib.sha256(seed.encode()).hexdigest(), 16)
    rng = random.Random(seed_hash)
    return [rng.randint(0, 2**31 - 1) for _ in range(n)]

# Example: Assign conditions
conditions = seeded_random("experiment_001", n=100)
treatment = conditions[:50]
control = conditions[50:]
```

---

### 1.3 Sample Size Justification

**Power Analysis Formula** (t-test):
```python
from scipy.stats import norm
import numpy as np

def sample_size_t_test(
    effect_size: float,
    alpha: float = 0.05,
    power: float = 0.80,
    ratio: float = 1.0
) -> int:
    """
    Required sample size for two-sample t-test.

    Args:
        effect_size: Cohen's d (0.2=small, 0.5=medium, 0.8=large)
        alpha: Significance level
        power: Desired power (1 - beta)
        ratio: n2/n1 ratio
    """
    z_alpha = norm.ppf(1 - alpha / 2)
    z_beta = norm.ppf(power)

    n_per_group = 2 * ((z_alpha + z_beta) / effect_size) ** 2
    n_total = int(np.ceil(n_per_group * (1 + ratio) ** 2 / (4 * ratio)))

    return n_total
```

---

## Part 2: Environment Reproducibility

### 2.1 Dependency Locking

**Trinity approach**: Pure Zig = zero external dependencies = 100% reproducible

```bash
# Zig stdlib is part of compiler - always available
# No package.json, requirements.txt, or go.sum needed

# Verify Zig version
zig version  # Should match: 0.15.0

# Build is deterministic with same Zig version
zig build
```

**For Python components** (kaggle/):
```bash
# Freeze exact versions
pip freeze > requirements.lock

# Or use pip-tools for dependency resolution
pip-compile requirements.in
```

---

### 2.2 Configuration Management

**Version-controlled config**:
```toml
# config/research.toml
[experiment]
name = "HSLM Training Wave 9"
seed = 42
date_started = "2026-03-26"

[model]
architecture = "HSLM-Medium"
layers = 24
hidden_dim = 2048
num_heads = 8

[training]
learning_rate = 0.001
lr_schedule = "cosine"
batch_size = 32
epochs = 50000
warmup = 1000

[data]
train_path = "data/wave9/worker-1/hslm_step_*.bin"
vocab_size = 50000
```

---

### 2.3 Seed Management

**Hierarchical seeding**:
```python
import struct
import hashlib

def seed_from_config(config: dict) -> int:
    """Generate deterministic seed from config hash."""
    config_str = str(sorted(config.items()))
    return int(hashlib.sha256(config_str.encode()).hexdigest(), 16) % (2**31)

# Trinity Zig approach
const SEED: u32 = 42; // Compile-time constant
var rng = std.Random.DefaultPrng.init(SEED);
```

---

## Part 3: Data Management

### 3.1 Data Provenance

**Metadata standard**:
```json
{
  "dataset_id": "wave9-worker1-hslm",
  "version": "1.0",
  "created": "2026-03-26T00:00:00Z",
  "source": "HSLM training farm",
  "size_bytes": 1234567890,
  "num_samples": 100000,
  "checksum_sha256": "abc123...",
  "parent_dataset": "wave8-worker1",
  "transformation_applied": "tokenization"
}
```

---

### 3.2 Data Versioning

**Trinity approach**: Content-addressed storage with hash-based naming

```zig
// src/vibeec/content_hash.zig
pub fn contentHash(source: []const u8) [32]u8 {
    // SHA-256 hash of content
    return std.crypto.hash.sha2.Sha256.hash(source);
}

// Filename: content_hash.json
// Ensures same data = same filename
```

---

### 3.3 Data Splitting

**Reproducible splits**:
```python
def deterministic_split(data: list, seed: int,
                         train: float = 0.7,
                         val: float = 0.15,
                         test: float = 0.15) -> dict:
    """
    Split data deterministically using seed.

    Returns: {train_indices, val_indices, test_indices}
    """
    import numpy as np
    rng = np.random.default_rng(seed)
    indices = np.arange(len(data))
    rng.shuffle(indices)

    n = len(indices)
    train_end = int(n * train)
    val_end = int(n * (train + val))

    return {
        'train': indices[:train_end],
        'val': indices[train_end:val_end],
        'test': indices[val_end:]
    }
```

---

## Part 4: Computational Reproducibility

### 4.1 Floating Point Determinism

**Challenge**: Floating point operations are not deterministic across platforms

**Solution**:
```zig
// Use fixed-point for critical comparisons
const EPSILON: f32 = 1e-6;

fn nearlyEqual(a: f32, b: f32) bool {
    return @abs(a - b) < EPSILON;
}

// For sorting: use stable sort
std.sort.insertion(StableSortContext, items);
```

---

### 4.2 Parallel Processing

**Trinity swarm**:
- Each agent has deterministic seed
- Results aggregation order doesn't matter
- Idempotent operations

```zig
// src/tri/farm/root.zig
pub const FARM_SEED: u64 = 42;

var worker_rng = std.Random.DefaultPrng.init(FARM_SEED + worker_id);
```

---

### 4.3 Result Verification

**Checksum validation**:
```python
def verify_results(results: dict, expected_checksums: dict) -> bool:
    """Verify that results match expected checksums."""
    import hashlib

    for key, value in results.items():
        if key in expected_checksums:
            value_str = json.dumps(value, sort_keys=True)
            checksum = hashlib.sha256(value_str.encode()).hexdigest()
            if checksum != expected_checksums[key]:
                return False
    return True
```

---

## Part 5: Reporting Standards

### 5.1 Results Reporting

**CONSORT-style table**:
```markdown
| Characteristic | v7.0 (n=1000) | v7.5 (n=1000) | p-value | Effect Size |
|----------------|---------------|---------------|---------|-------------|
| ECE | 0.12 [0.10, 0.14] | 0.09 [0.07, 0.11] | 0.023* | d=0.32 (small) |
| Brier Score | 0.16 | 0.14 | 0.015* | d=0.28 (small) |
| Min-K%++ CI | Arbitrary | Actual metric | — | — |

*p < 0.05
```

---

### 5.2 Code Availability

**GitHub repository structure**:
```
github.com/gHashTag/trinity/
├── src/              # All source code
├── specs/            # .tri specifications (source of truth)
├── build.zig         # Build system
├── README.md         # Setup instructions
├── LICENSE           # MIT License
├── CITATION.cff      # Citation metadata
└── docs/             # Documentation
```

**Version tags**: `v7.0`, `v7.5`, etc.

---

### 5.3 Docker Reproducibility

**Multi-stage Dockerfile**:
```dockerfile
# Build stage
FROM ziglang/zig:0.15.0 AS builder
WORKDIR /app
COPY . .
RUN zig build -Drelease-fast

# Runtime stage
FROM alpine:latest
COPY --from=builder /app/zig-out/bin/* /usr/local/bin/
CMD ["tri"]
```

---

## Part 6: Statistical Reporting

### 6.1 Effect Size Interpretation

**Cohen's d benchmarks**:
```python
def interpret_cohens_d(d: float) -> str:
    """Interpret Cohen's d effect size."""
    abs_d = abs(d)
    if abs_d < 0.2:
        return "negligible"
    elif abs_d < 0.5:
        return "small"
    elif abs_d < 0.8:
        return "medium"
    else:
        return "large"
```

---

### 6.2 Confidence Interval Reporting

**Template**:
```markdown
## Results

Primary metric (ECE): 0.09 (95% CI [0.07, 0.11])

Interpretation: We are 95% confident that the true ECE lies between 0.07 and 0.11.

Comparison to baseline (v7.0): Δ = -0.03 (95% CI [-0.05, -0.01], p = 0.023)
```

---

### 6.3 Negative Results

**Important**: Report null findings

```markdown
## Null Finding

Hypothesis: Adaptive binning improves ECE by >5%.

Result: Mean improvement = 2.3% (95% CI [-1.2%, 5.8%], p = 0.21)

Conclusion: No statistically significant improvement detected.
```

---

## Part 7: Version Control Best Practices

### 7.1 Commit Messages

**Conventional commits** (used in Trinity):
```
feat(scope): description
fix(scope): description
docs(scope): description
refactor(scope): description
test(scope): description
chore(scope): description
```

**Example**:
```
feat(tri-lang): add emu export to root.zig

Fixes build error where tri27_cli.zig was trying to access
tri_lang.emu.* but root.zig didn't re-export it from gen_root.zig.
```

---

### 7.2 Branching Strategy

```
main                  # Production releases
├── feat/issue-411    # Feature branches
│   ├── commit 1
│   ├── commit 2
│   └── commit 3
└── develop           # Development branch
```

---

### 7.3 Tagging Releases

```bash
# Annotated tag for releases
git tag -a v7.5 -m "Scientific Metrics v7.5"

# Push tags
git push origin v7.5
```

---

## Part 8: Open Science Integration

### 8.1 Zenodo Integration

**Automated DOI creation**:
```bash
# Create Zenodo release from GitHub tag
zenodo create v7.5 \
  --title "Scientific Metrics v7.5" \
  --authors "Dmitrii Vasilev" \
  --description "$(cat docs/release_notes_v7.5.md)"
```

---

### 8.2 ORCID Integration

**Include in all publications**:
```
Dmitrii Vasilev https://orcid.org/0000-0000-0000-0000
Trinity S³AI https://github.com/gHashTag/trinity
```

---

### 8.3 Citation Metrics

**Track your citations**:
1. Google Scholar profile
2. ORCID profile (auto-updates)
3. GitHub README citation badge

---

## Part 9: Quality Assurance Checklist

### Before Publishing Results

- [ ] Code compiles without warnings (`zig build`)
- [ ] All tests pass (`zig test`)
- [ ] Code formatted (`zig fmt`)
- [ ] Results reproducible on different machines
- [ ] Random seeds documented
- [ ] Sample sizes justified
- [ ] Effect sizes reported
- [ ] Confidence intervals included
- [ ] Negative findings reported
- [ ] Code available under open license

---

## Part 10: Trinity-Specific Patterns

### 10.1 VIBEE Code Generation

**Source of truth**: `.tri` specifications

```bash
# Generate from spec
zig build vibee -- gen specs/tri-lang/type_env.tri

# Output: src/tri-lang/gen_type_env.zig
# DO NOT EDIT - Generated file
```

---

### 10.2 Self-Hosting (TTT Dogfood)

**Switch between manual/generated**:
```zig
// root.zig
const gen = @import("gen_root.zig");  // Self-hosted
// const manual = @import("root_manual.zig");  // Manual
```

---

### 10.3 Pure Zig Philosophy

**No external dependencies**:
- ✅ Zero Python
- ✅ Zero Bash scripts
- ✅ Zero package managers
- ✅ 100% Zig stdlib

**Benefits**:
- Perfect reproducibility
- No dependency hell
- Single binary compilation
- Cross-platform consistency

---

## References

1. **NSF** (2024). "Replicability and Reproducibility in Computer Science"
2. **FORCE11** (2024). "Data Citation Principles"
3. **Open Science Framework** (2023). "Transparency, Openness, and Reproducibility"
4. **CONSORT** (2010). "Consolidated Standards of Reporting Trials"
5. **Efron & Hastie** (2016). "Computer Age Statistical Inference"

---

**Document Version**: 1.0
**Last Updated**: 2026-03-26
**Author**: Dmitrii Vasilev
**Status**: Ready for Use
