# Enhanced Reproducibility Guide for Trinity Publications

**Version:** 2.0.0
**Date:** 2026-03-26
**Purpose:** Complete reproducibility instructions for all 7 Zenodo bundles

---

## Quick Start

### Prerequisites

```bash
# Install Zig 0.15.x
brew install zig

# Clone repository
git clone https://github.com/gHashTag/trinity
cd trinity

# Checkout specific version (replace <TAG> with actual tag)
git checkout <TAG>
```

### Verify Installation

```bash
# Check Zig version
zig version  # Expected: 0.15.x

# Run tests
zig build test

# Expected output:
# VSA Correctness:      25.0/25.0
# VM Correctness:       25.0/25.0
# SDK Correctness:      25.0/25.0
# Memory Efficiency:    15.0/15.0
# Performance:          10.0/10.0
# TOTAL SCORE:         100.0/100.0
```

---

## Bundle-Specific Reproducibility

### B001: Ternary Neural Networks

**Dataset:** TinyStories (2M stories, 33M tokens)

```bash
# Download dataset (if not already present)
python3 scripts/download_tinystories.py

# Train HSLM model
zig build hslm-train
./zig-out/bin/hslm-train \
  --dataset data/tinystories \
  --steps 30000 \
  --lr 0.001 \
  --lr-schedule cosine \
  --checkpoint-interval 5000

# Expected final PPL: ~124
# Expected training time: ~4 hours on M1 Max
```

**Checkpoint Verification:**

```bash
# Verify checkpoint integrity
zig build verify-checkpoint
./zig-out/bin/verify-checkpoint \
  --checkpoint data/hslm_step_30000.bin \
  --expected-ppl 124.1
```

### B002: Zero-DSP FPGA

**Hardware:** Xilinx XC7A100T-CSG324
**Toolchain:** Yosys 0.38+ + nextpnr-xilinx

```bash
cd fpga/openxc7-synth

# Synthesize HSLM bitstream
make hslm_bitstream

# Expected resources:
# LUT: 12,433 (19.6%)
# DSP: 0 (0%)
# BRAM: 12 (8.9%)
# Power: 1.2W @ 50MHz

# Flash to FPGA
make flash
```

### B003: TRI-27 ISA

```bash
# Run TRI-27 VM tests
zig build tri27-test
./zig-out/bin/tri27-test

# Expected: All 68 tests passing

# Run benchmark programs
zig build tri27-bench
./zig-out/bin/tri27-bench --program fibonacci --n 20
./zig-out/bin/tri27-bench --program sort --size 100
```

### B004: Queen Lotus Cycle

```bash
# Run self-learning tests
zig build queen-test
./zig-out/bin/queen-test --test self_learning

# Expected: All 4 tests passing

# View episode database
zig build queen-inspect
./zig-out/bin/queen-inspect --database .trinity/queen/episodes.db
```

### B005: Tri Language

```bash
# Compile .tri spec
zig build vibee
./zig-out/bin/vibee gen specs/tri/dense_layer.tri --output zig

# Type checking
zig build tri-lang-check
./zig-out/bin/tri-lang-check specs/tri/dense_layer.tri
```

### B006: Sacred GF16/TF3

```bash
# Test GF16 encoding
zig build test-sacred-formats
zig test src/sacred_formats_test.zig

# Expected accuracy vs FP32: <1% MSE
```

### B007: VSA Operations

```bash
# VSA correctness tests
zig build test-vsa
zig test src/vsa/vsa.zig

# Benchmark (729x729, 1000 iterations)
zig build bench-vsa-simd
./zig-out/bin/bench-vsa-simd --size 729 --iter 1000

# Expected SIMD speedup: ~11-12x
```

---

## Docker Reproducibility

### Dockerfile

```dockerfile
FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Zig
RUN wget https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz \
    && tar -xzf zig-linux-x86_64-0.15.2.tar.xz \
    && mv zig-linux-x86_64-0.15.2/zig /usr/local/bin/ \
    && rm zig-linux-x86_64-0.15.2.tar.xz

# Install Python dependencies
RUN pip3 install numpy scipy

# Copy repository
WORKDIR /workspace
COPY . .

# Build
RUN zig build test

# Run tests
CMD ["zig", "build", "test"]
```

### Build and Run

```bash
# Build image
docker build -t trinity-research:latest .

# Run tests
docker run --rm trinity-research:latest zig build test
```

---

## Random Seed Reproducibility

All experiments use fixed random seeds for reproducibility:

```zig
// Fixed seed for reproducibility
const DEFAULT_SEED: u64 = 0xAEDD4D0;

var prng = std.Random.DefaultPrng.init(DEFAULT_SEED);
```

To reproduce exact results:

```bash
# Set environment variable
export TRINITY_SEED=0xAEDD4D0

# Run experiment
zig build experiment
./zig-out/bin/experiment --seed $TRINITY_SEED
```

---

## Statistical Validation

### Confidence Intervals

All reported metrics include 95% confidence intervals:

```python
import numpy as np
from scipy import stats

def compute_ci(values: np.ndarray, confidence: float = 0.95) -> tuple:
    """Compute confidence interval for mean."""
    n = len(values)
    mean = np.mean(values)
    std = np.std(values, ddof=1)
    se = std / np.sqrt(n)

    t_val = stats.t.ppf((1 + confidence) / 2, n - 1)
    margin = t_val * se

    return mean, mean - margin, mean + margin

# Example: PPL from multiple runs
ppl_values = [124.1, 123.8, 124.5, 124.2, 123.9]
mean, lower, upper = compute_ci(ppl_values)
print(f"PPL: {mean:.2f} [{lower:.2f}, {upper:.2f}]")
```

### Bootstrap Validation

```python
def bootstrap_ci(values: np.ndarray, n_bootstrap: int = 10000) -> tuple:
    """Compute bootstrap confidence interval."""
    boot_means = []
    for _ in range(n_bootstrap):
        sample = np.random.choice(values, size=len(values), replace=True)
        boot_means.append(np.mean(sample))

    return np.percentile(boot_means, [2.5, 97.5])
```

---

## Hardware-Specific Results

### Apple M1 Max

| Component | Value |
|-----------|-------|
| CPU | 8 performance cores @ 3.2 GHz |
| Memory | 64 GB unified |
| Storage | 1 TB SSD |
| OS | macOS 15.4 |

### Xilinx XC7A100T

| Resource | Value |
|----------|-------|
| LUT | 63,400 |
| FF | 126,800 |
| DSP | 240 |
| BRAM | 135 (36Kb each) |

---

## Expected Results Summary

| Bundle | Metric | Expected | Actual | Status |
|--------|--------|----------|--------|--------|
| B001 | Final PPL | 124.1 | TBD | - |
| B002 | LUT % | 19.6% | TBD | - |
| B003 | VM Tests | 68/68 | 68/68 | ✓ |
| B004 | Self-Learning | 4/4 | 4/4 | ✓ |
| B005 | Codegen | ✓ | TBD | - |
| B006 | Accuracy | <1% MSE | TBD | - |
| B007 | SIMD Speedup | 11-12x | 11.76x | ✓ |

---

## Troubleshooting

### Build Failures

```bash
# Clean and rebuild
zig build clean
zig build

# If that fails, check Zig version
zig version  # Must be 0.15.x
```

### Test Failures

```bash
# Run tests with verbose output
zig test test-all --summary all

# Run specific test
zig test src/vsa/vsa.zig --test-name "vsa bind"
```

### FPGA Issues

```bash
# Check cable connection
lsusb | grep Xilinx

# Load firmware
fxload -t fx2 -I 0x03fd -D 0x0013 /usr/share/usbprog/xilinx_swt2.hex
```

---

## Version Compatibility Matrix

| Bundle | Zig Version | Python | FPGA Toolchain |
|--------|-------------|--------|----------------|
| B001 | 0.15.x | 3.10+ | - |
| B002 | 0.15.x | - | Yosys 0.38+ |
| B003 | 0.15.x | - | - |
| B004 | 0.15.x | - | - |
| B005 | 0.15.x | - | - |
| B006 | 0.15.x | - | - |
| B007 | 0.15.x | - | - |

---

## Contact

For reproducibility issues:
- GitHub Issues: https://github.com/gHashTag/trinity/issues
- Documentation: https://github.com/gHashTag/trinity/wiki

---

**φ² + 1/φ² = 3 | TRINITY**
