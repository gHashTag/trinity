# Trinity Research — Reproducibility Quick-Start

## Overview

This guide provides step-by-step instructions for reproducing key experimental results from Trinity S³AI research, including HSLM training, FPGA synthesis, and scientific metrics evaluation.

**Version**: 1.0.0
**Last Updated**: 2026-03-26
**Status**: Ready for Review

---

## Prerequisites

### Hardware Requirements

| Experiment | CPU | RAM | FPGA | Storage |
|------------|-----|-----|------|---------|
| HSLM Training | 4+ cores | 8 GB | Optional | 5 GB |
| FPGA Synthesis | 2+ cores | 4 GB | XC7A100T | 2 GB |
| Scientific Metrics | 2+ cores | 4 GB | - | 1 GB |

### Software Requirements

```bash
# Core dependencies
zig version 0.15.x      # https://ziglang.org/download/
git version 2.x+        # https://git-scm.com/
docker version 20.x+    # Optional, for containerized training

# FPGA tools (optional)
yosys version 0.45+     # https://yosyshq.net/yosys/
nextpnr-xilinx         # https://github.com/YosysHQ/nextpnr
```

### Installation

```bash
# 1. Install Zig
# macOS
brew install zig

# Linux
# Download from https://ziglang.org/download/ and add to PATH

# 2. Clone repository
git clone https://github.com/gHashTag/trinity
cd trinity

# 3. Verify build
zig build
./zig-out/bin/tri --version
# Expected: Trinity v0.x.x
```

---

## Experiment 1: HSLM Inference

### Objective

Run text generation with pre-trained HSLM checkpoint (1.95M params, PPL=125).

### Steps

```bash
# 1. Download checkpoint
# (Pre-trained checkpoint available in data/hslm_step_30000.bin)
# Or train your own using Experiment 2

# 2. Build HSLM inference binary
zig build hslm-inference

# 3. Run inference
./zig-out/bin/hslm-inference \
    --checkpoint data/hslm_step_30000.bin \
    --prompt "Once upon a time" \
    --tokens 50 \
    --temperature 0.8

# Expected output:
# Generated text (~50 tokens) with coherent story continuation
# Throughput: ~50-100 tok/s on M1 Pro
```

### Verification

```bash
# Run HSLM tests
zig build test --test-filter "HSLM"

# Expected: All tests pass
# - Checkpoint loading
# - Forward pass
# - Token generation
# - PPL calculation
```

### Expected Results

| Metric | Value | Range |
|--------|-------|-------|
| Checkpoint size | 385 KB | 380-390 KB |
| Inference speed | 50-100 tok/s | CPU-dependent |
| Perplexity | 125 | 120-130 |
| Coherence | Subjective | Stories make sense |

---

## Experiment 2: HSLM Training (Optional)

### Objective

Train HSLM from scratch on TinyStories dataset.

### Prerequisites

```bash
# 1. Download TinyStories dataset
# https://huggingface.co/datasets/roneneldan/TinyStories
# Save to data/TinyStories/

# 2. Prepare dataset
python3 scripts/prepare_tinystories.py \
    --input data/TinyStories/TinyStories_all.txt \
    --output data/tinystories.bin \
    --vocab-size 2048

# Expected: data/tinystories.bin (~45M tokens)
```

### Training Configuration

```bash
# 3. Build training binary
zig build hslm-train

# 4. Run training
./zig-out/bin/hslm-train \
    --dataset data/tinystories.bin \
    --output-dir data/wave9/ \
    --batch-size 64 \
    --lr-max 1e-3 \
    --lr-schedule cosine \
    --warmup-steps 2000 \
    --total-steps 30000 \
    --checkpoint-interval 5000

# Expected duration: ~4 hours on 8 cores
# Expected final PPL: 120-130
```

### Training Curve

```
Step     PPL    Loss      Time
--------------------------------------
0        2500   7.82      0:00:00
5000     450    6.11      0:40:00
10000    220    5.39      1:20:00
15000    165    5.11      2:00:00
20000    140    4.94      2:40:00
25000    130    4.87      3:20:00
30000    125    4.83      4:00:00
```

### Verification

```bash
# Plot training curve
python3 scripts/plot_training.py \
    --checkpoint data/wave9/worker-1/hslm_step_30000.bin \
    --output training_curve.png

# Expected: Monotonically decreasing PPL
```

---

## Experiment 3: FPGA Synthesis

### Objective

Synthesize ternary MAC unit for Artix-7 FPGA.

### Steps

```bash
# 1. Navigate to FPGA directory
cd fpga/openxc7-synth

# 2. Synthesize sacred ALU
yosys sacred_alu.v -p "synth_xilinx -o sacred_alu_synth.v"

# Expected: sacred_alu_synth.v (synthesized Verilog)

# 3. Run PnR (place-and-route)
nextpnr-xilinx --chip xc7a100t-csg324-1 \
    --json sacred_alu.json \
    --pcf sacred_alu.pcf \
    --xc7 sacred_alu_synth.v

# Expected: sacred_alu.json (routed design)

# 4. Generate timing report
# Check nextpnr output for:
# - Max frequency: >= 100 MHz
# - Setup/Hold time: PASSED
# - Resource usage
```

### Expected Results

| Resource | Used | Total | Percentage |
|----------|------|-------|------------|
| LUT | ~50 | 80,600 | 0.06% |
| FF | ~30 | 161,200 | 0.02% |
| DSP | 0 | 240 | 0% |
| BRAM | 0 | 730 | 0% |

### Verification

```bash
# Check synthesis report
grep -A 20 "Number of cells" sacred_alu.log

# Expected: 0 DSP48E1 used
```

---

## Experiment 4: Scientific Metrics v7

### Objective

Compute Cognitive Probes v7 metrics (Min-K%++, Full-ECE, contamination detection).

### Steps

```bash
# 1. Install Python dependencies
pip install numpy scipy scikit-learn matplotlib

# 2. Run scientific metrics
python3 kaggle/eval/scientific_metrics_v7.py \
    --checkpoint data/hslm_step_30000.bin \
    --dataset data/TinyStories_test.txt \
    --output metrics.json

# Expected: metrics.json with:
# - min_k_percent
# - full_ece
# - contamination_score
# - temperature_optimal
```

### Expected Results

| Metric | Value | Range |
|--------|-------|-------|
| Min-K%++ (K=1%) | 0.85 | 0.80-0.90 |
| Full-ECE | 0.12 | 0.10-0.15 |
| Contamination | 0.05 | 0.00-0.10 |
| Optimal T | 0.8 | 0.7-1.0 |

### Verification

```bash
# Plot calibration curve
python3 kaggle/eval/visualization.py \
    --metrics metrics.json \
    --output calibration.png

# Expected: Well-calibrated (close to diagonal)
```

---

## Experiment 5: VSA Operations

### Objective

Verify VSA (Vector Symbolic Architecture) mathematical properties.

### Steps

```bash
# 1. Build VSA test binary
zig build vsa-test

# 2. Run VSA tests
./zig-out/bin/vsa-test \
    --dimensions 10000 \
    --iterations 1000

# Expected output:
# bind/unbind: 100% recovery
# cosine similarity: [-1, 1]
# hamming similarity: [0, 1]
```

### Verification

```bash
# Run formal verification
zig build test --test-filter "VSA"

# Expected: All proofs pass
# - bind(unbind(a, b), b) ≈ a
# - bundle(a, a) ≈ a
# - sim(a, a) = 1
```

---

## Experiment 6: TRI-27 ISA

### Objective

Run TRI-27 assembly program on CPU emulator.

### Steps

```bash
# 1. Write TRI-27 program
cat > test.t27 << 'EOF'
; Compute Fibonacci sequence
LDI t0, 0      ; fib(0) = 0
LDI t1, 1      ; fib(1) = 1
LDI t2, 10     ; compute first 10 numbers

loop:
ADD t3, t0, t1 ; fib(n) = fib(n-1) + fib(n-2)
MOV t0, t1     ; shift
MOV t1, t3     ; shift
DEC t2         ; counter--
JNZ loop       ; repeat if t2 != 0

HALT
EOF

# 2. Assemble program
./zig-out/bin/tri27 assemble test.t27 -o test.tbin

# 3. Execute
./zig-out/bin/tri27 run test.tbin

# Expected: t3 contains Fibonacci numbers
```

### Verification

```bash
# Run TRI-27 tests
zig build test --test-filter "TRI27"

# Expected: All 15+ tests pass
# - All opcodes execute correctly
# - Flags are set properly
# - Memory access works
```

---

## Containerized Reproduction (Optional)

### Docker Setup

```bash
# 1. Build Docker image
docker build -f deploy/Dockerfile.hslm-train -t trinity-hslm .

# 2. Run container
docker run -v $(pwd)/data:/app/data trinity-hslm \
    tri hslm train --dataset /app/data/tinystories.bin

# 3. Access results
ls -lh data/hslm_step_*.bin
```

### Railway Deployment (Optional)

```bash
# 1. Install Railway CLI
npm install -g @railway/cli

# 2. Login
railway login

# 3. Link project
railway link

# 4. Deploy HSLM training
railway up
# Set environment variables:
#   HSLM_LR_MAX=1e-3
#   HSLM_LR_SCHEDULE=cosine
#   HSLM_DATASET=/data/tinystories.bin

# 5. Monitor logs
railway logs
```

---

## Troubleshooting

### Build Errors

```bash
# Zig version mismatch
zig version  # Must be 0.15.x

# Clear build cache
rm -rf zig-cache/ zig-out/
zig build
```

### Training Issues

```bash
# Dataset not found
ls -lh data/tinystories.bin

# Check learning rate
# LR too high: Loss explodes
# LR too low: Loss doesn't decrease

# Adjust: --lr-max 5e-4 (try 5e-4 to 5e-3 range)
```

### FPGA Synthesis Failures

```bash
# Yosys not found
which yosys

# Install via package manager
# macOS: brew install yosys
# Ubuntu: apt install yosys

# Check Verilog syntax
yosys -p "hierarchy -check sacred_alu.v"
```

---

## Verification Checklist

Before claiming reproducibility, verify:

- [ ] Build succeeds (`zig build`)
- [ ] All tests pass (`zig build test`)
- [ ] HSLM inference works (`./zig-out/bin/hslm-inference`)
- [ ] Checkpoint size ≈ 385 KB
- [ ] FPGA synthesis completes (0 DSP)
- [ ] Scientific metrics compute successfully
- [ ] VSA operations verify mathematically
- [ ] TRI-27 emulator runs programs

---

## Contact

For issues or questions:
- GitHub Issues: https://github.com/gHashTag/trinity/issues
- Documentation: https://github.com/gHashTag/trinity/blob/main/docs/research/README.md

---

**φ² + 1/φ² = 3 | TRINITY**
