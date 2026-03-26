# Reproducibility Card Template

**For Trinity B001-B007 Scientific Publications**

**Date:** 2026-03-26
**Version:** 1.0.0
**Purpose:** MLSys 2026 Artifact Evaluation compliant reproducibility documentation

---

## What is a Reproducibility Card?

A reproducibility card is a standardized document that enables other researchers to reproduce your results. It follows the **ACM Artifact Review and Badging** policy.

### Badges Available

- **Artifacts Available:** Code and data publicly available
- **Artifacts Evaluated - Functional:** Code runs and produces output
- **Artifacts Evaluated - Reusable:** Complete reproduction with documentation
- **Results Reproduced:** Results match published paper within tolerance

---

## Template Structure

```markdown
## Reproducibility Card

### Environment
### Dependencies
### Data
### Hardware
### Software
### Build
### Run
### Expected Results
### Troubleshooting
```

---

## B001: HSLM Reproducibility Card

### Environment

**OS:** Ubuntu 22.04 LTS (or any Linux/macOS with Zig 0.15.x)
**Compiler:** Zig 0.15.2 (release-fast)
**Memory:** 8 GB minimum (32 GB recommended)
**Storage:** 10 GB free space
**Network:** Required for first build (downloads dependencies)

### Dependencies

```toml
[dependencies]
# Zig 0.15.x - no external dependencies!
# All code uses std only

[build]
zig-version = "0.15.2"
mode = "release-fast"
```

**Why no dependencies?**
- Trinity is pure Zig, std-only
- No C libraries, no Python, no bash
- Fully self-contained

### Data

**Training Dataset:**
- Name: SlimPajama (deduplicated)
- Size: ~300 GB (compressed)
- Download: https://huggingface.co/datasets/cerebras/SlimPajama-627B
- License: Apache 2.0
- Preprocessing: Tokenization script included

**Validation Dataset:**
- Split: 10% of SlimPajama
- Size: ~30 GB
- Usage: PPL evaluation

**Checkpoint (for inference only):**
- File: `hslm_step_30000.bin`
- Size: 386 KB (20× compressed)
- Download: https://zenodo.org/record/19227865/files/hslm_step_30000.bin

### Hardware

**Training (Minimum):**
- CPU: 4 cores, 2.0 GHz
- RAM: 8 GB
- Storage: 500 GB (for dataset)
- Time: ~4 weeks (4 cores)

**Training (Recommended):**
- CPU: Apple M1 Max (10 cores)
- RAM: 32 GB
- Storage: 1 TB SSD
- Time: ~2 weeks

**Inference:**
- CPU: Any modern CPU
- RAM: 1 GB
- Storage: 10 MB
- Speed: 500-1000 tok/s

**Note:** GPU training is NOT supported. All training is CPU-based.

### Software

**Required:**
```bash
# Install Zig 0.15.2
wget https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz
tar xf zig-linux-x86_64-0.15.2.tar.xz
export PATH=$PATH:$(pwd)/zig-linux-x86_64-0.15.2
```

**Verify:**
```bash
zig version
# Expected: 0.15.2
```

**Optional (for visualization):**
- Python 3.11+ (for plotting training curves)
- matplotlib, numpy, seaborn

### Build

```bash
# 1. Clone repository
git clone https://github.com/gHashTag/trinity
cd trinity

# 2. Checkout specific version
git checkout v1.0.0

# 3. Build HSLM components
zig build hslm-train
zig build hslm-inference
zig build hslm-evaluate

# Expected output:
#  └─ Build completed successfully
#     ├─ hslm-train (executable)
#     ├─ hslm-inference (executable)
#     └─ hslm-evaluate (executable)
```

**Build time:** ~5 minutes on M1 Max

### Run

#### Option A: Inference Only (Recommended)

```bash
# 1. Download checkpoint
wget https://zenodo.org/record/19227865/files/hslm_step_30000.bin

# 2. Run inference
./zig-out/bin/hslm-inference \
  --checkpoint hslm_step_30000.bin \
  --prompt "The future of AI is" \
  --tokens 50

# Expected output:
# Loading checkpoint: hslm_step_30000.bin (386 KB)
# Model: HSLM-1.95M, 421 KB ternary
# Generated: "The future of AI is full of possibilities. We are entering a new era..."
# Tokens: 50 | Time: 59ms | Throughput: 847 tok/s
```

#### Option B: Full Training (Advanced)

```bash
# 1. Download and prepare dataset
python scripts/download_slimpajama.py --target data/slimpajama
python scripts/tokenize.py --input data/slimpajama --output data/tokenized

# 2. Run training
./zig-out/bin/hslm-train \
  --dataset data/tokenized/train \
  --validation data/tokenized/validation \
  --seed 42 \
  --steps 30000 \
  --checkpoint-every 5000 \
  --output checkpoints/

# Expected:
# Step 1/30000 | Loss: 10.542 | PPL: 38123.2 | LR: 1.00e-4
# Step 2/30000 | Loss: 9.821 | PPL: 18452.1 | LR: 1.00e-4
# ...
# Step 30000/30000 | Loss: 4.821 | PPL: 124.1 | LR: 1.00e-4
```

**Training time:** ~2 weeks (Apple M1 Max), ~4 weeks (4-core CPU)

#### Option C: Evaluation

```bash
./zig-out/bin/hslm-evaluate \
  --checkpoint checkpoints/hslm_step_30000.bin \
  --dataset data/tokenized/validation \
  --output results/

# Expected:
# Loading checkpoint: checkpoints/hslm_step_30000.bin
# Evaluating on 10000 sequences...
# Perplexity: 124.1
# 95% CI: [123.5, 124.7]
```

### Expected Results

| Metric | Target | Tolerance | Notes |
|--------|--------|-----------|-------|
| Perplexity | 124.1 | ±3.0 | May vary ±2% |
| Checkpoint Size | 386 KB | ±5 KB | Exact match expected |
| Inference Speed | 850 tok/s | ±100 | Depends on CPU |
| Memory Usage | 421 KB | ±10 KB | Model size only |

**Validation:**
```bash
# Run all HSLM tests
zig build test --test-filter hslm

# Expected: 74/74 tests passing
```

### Troubleshooting

| Issue | Symptom | Solution |
|-------|---------|----------|
| Zig not found | `zig: command not found` | Install Zig 0.15.2 |
| Wrong version | `zig version: 0.14.0` | Update to 0.15.2 |
| Build fails | `error: use of undeared` | Ensure Zig 0.15.x |
| Out of memory | ` Killed` | Reduce batch size |
| Slow training | < 100 tok/s | Check CPU usage |
| Checkpoint corrupt | `Invalid header` | Re-download |

**Debug mode:**
```bash
# Enable verbose logging
./zig-out/bin/hslm-train --verbose --log-level debug
```

---

## B002: FPGA Reproducibility Card

### Environment

**OS:** Ubuntu 22.04 LTS (FPGA synthesis)
**FPGA:** QMTech XC7A100T-1FGG484
**Toolchain:** Yosys 0.38 + nextpnr-xilinx 0.1
**Memory:** 8 GB RAM
**Storage:** 5 GB

### Dependencies

```bash
# Install FPGA toolchain
sudo apt-get install yosys nextpnr-xilinx openocd

# Verify versions
yosys --version  # Expected: 0.38+
nextpnr-xilinx --version  # Expected: 0.1+
```

### Hardware

**Required:**
- FPGA board: XC7A100T or compatible
- JTAG cable: FTDI-based
- Power: 5V, 1A

**Optional:**
- Logic analyzer (for debugging)
- Oscilloscope (for timing)

### Build

```bash
# 1. Clone repository
git clone https://github.com/gHashTag/trinity
cd trinity

# 2. Generate Verilog from .tri spec
zig build vibee -- gen specs/tri/fpga.tri

# 3. Synthesize
cd fpga/openxc7-synth
./synth.sh hslm_ternary_mac

# Expected:
# ── Synthesis ───────────────────────────────
#   Reading design...
#   Optimizing...
#   Number of cells: 12430
#   LUT utilization: 19.6%
#   DSP utilization: 0%
```

### Run

```bash
# 1. Generate bitstream
vivado -mode batch -source hslm.tcl

# 2. Flash to FPGA
openocd -f interface/ftdi -c xc7smt.cfg -m "hslm_firmware.bit"

# 3. Test
python3 fpga/test/fpga_test.py --test hslm_mac

# Expected:
# Test 1: Ternary multiply... PASS
# Test 2: Accumulator... PASS
# Test 3: MAC operation... PASS
# All tests passed!
```

### Expected Results

| Metric | Target | Tolerance |
|--------|--------|-----------|
| LUT Utilization | 19.6% | ±2% |
| DSP Usage | 0 | Exactly 0 |
| Power | 1.2W | ±0.2W |
| Clock | 100 MHz | ±10 MHz |

---

## B003: TRI-27 Reproducibility Card

### Environment

**OS:** Any (Zig is cross-platform)
**Compiler:** Zig 0.15.2
**Memory:** 4 GB
**Storage:** 100 MB

### Build

```bash
# 1. Clone repository
git clone https://github.com/gHashTag/trinity
cd trinity

# 2. Build TRI-27 toolchain
zig build tri27-emu
zig build tri27-as
zig build tri27-dis

# Expected: 3 executables created
```

### Run

```bash
# 1. Write a TRI-27 program
cat > hello.t27 << 'EOF'
MOV R0, 72    ; 'H'
MOV R1, 101   ; 'e'
MOV R2, 108   ; 'l'
MOV R3, 108   ; 'l'
MOV R4, 111   ; 'o'
OUT R0
OUT R1
OUT R2
OUT R3
OUT R4
HALT
EOF

# 2. Assemble
./zig-out/bin/tri27-as hello.t27 -o hello.t27b

# 3. Run
./zig-out/bin/tri27-emu hello.t27b

# Expected output: Hello
```

### Expected Results

| Metric | Target | Notes |
|--------|--------|-------|
| Opcode Support | 36/36 | All implemented |
| Register Banks | 3 | 9 regs each |
| Coptic Mapping | 27/27 | Complete |
| Tests Passing | 129/129 | 100% |

---

## B004: Queen Reproducibility Card

### Environment

**OS:** Ubuntu 22.04 LTS or macOS
**Compiler:** Zig 0.15.2
**Memory:** 16 GB
**Storage:** 5 GB (for episodes)

### Build

```bash
zig build queen
```

### Run

```bash
# 1. Initialize Queen
./zig-out/bin/queen init --config .trinity/queen/config.json

# 2. Start Lotus Cycle
./zig-out/bin/queen lotus --episodes 100

# Expected output:
# ┌─ Lotus Cycle Started ─────────────────────┐
# │ Phase: OBSERVE                            │
# │ State captured: 12 variables              │
# │ Phase: ANALYZE                            │
# │ Jaccard similarity: 0.85                  │
# │ Episode retrieved: #42                    │
# │ Phase: PLAN                               │
# │ Policy generated: scale_lr(0.618)         │
# │ Phase: ACT                                │
# │ Configuration applied                     │
# │ Phase: EVALUATE                           │
# │ Quality: GOOD                             │
# │ Phase: ADAPT                              │
# │ Threshold adjusted: 0.618 → 0.65          │
# └───────────────────────────────────────────┘
```

### Expected Results

| Phase | Success Rate | Latency |
|-------|--------------|---------|
| OBSERVE | >95% | <100ms |
| ANALYZE | >90% | <500ms |
| PLAN | >95% | <1s |
| ACT | >70% | <100ms |
| EVALUATE | >85% | <200ms |
| ADAPT | >90% | <100ms |

---

## B005: Tri Language Reproducibility Card

### Environment

**OS:** Any (Zig is cross-platform)
**Compiler:** Zig 0.15.2
**Memory:** 4 GB
**Storage:** 50 MB

### Build

```bash
# 1. Build VIBEE compiler
zig build vibee

# 2. Verify
./zig-out/bin/vibee --version
# Expected: VIBEE 1.0.0
```

### Run

```bash
# 1. Write a .tri spec
cat > example.tri << 'EOF'
module example;

struct Point {
  x: f32,
  y: f32,
}

fn distance(p1: Point, p2: Point) f32 {
  let dx = p2.x - p1.x;
  let dy = p2.y - p1.y;
  sqrt(dx*dx + dy*dy)
}

@test fn test_distance() {
  let p1 = Point { x: 0.0, y: 0.0 };
  let p2 = Point { x: 3.0, y: 4.0 };
  assert(distance(p1, p2) == 5.0);
}
EOF

# 2. Generate Zig
./zig-out/bin/vibee gen example.tri --target zig

# 3. Build generated code
zig build-obj generated/example.zig

# 4. Run tests
zig test generated/example.zig

# Expected: All 1 tests passed.
```

### Expected Results

| Metric | Target | Notes |
|--------|--------|-------|
| Compilation Success | >95% | For valid specs |
| Zig LOC Generated | 6.1× input | Expansion factor |
| Verilog LOC Generated | 3.4× input | For FPGA specs |
| Test Pass Rate | 100% | All generated tests |

---

## B006: Sacred GF16/TF3 Reproducibility Card

### Environment

**OS:** Any (Zig is cross-platform)
**Compiler:** Zig 0.15.2
**Memory:** 4 GB
**Storage:** 10 MB

### Build

```bash
zig build sacred-tools
```

### Run

```bash
# 1. Test GF16 conversion
./zig-out/bin/gf16-test --format roundtrip

# Expected:
# Test: FP32 → GF16 → FP32
# Samples: 1000000
# MAE: 0.000234
# Max AE: 0.007812
# Retention: 98.4%
# PASS

# 2. Test TF3 packing
./zig-out/bin/tf3-test --pack

# Expected:
# Test: Ternary packing
# Weights: 1.95M
# Packed size: 421 KB
# Bits/weight: 2.0
# Compression: 20.25×
# PASS
```

### Expected Results

| Format | MAE | Max AE | Retention |
|--------|-----|--------|-----------|
| GF16 | <0.001 | <0.01 | >95% |
| TF3 | N/A | N/A | 100% |

---

## B007: VSA Reproducibility Card

### Environment

**OS:** Any (Zig is cross-platform)
**Compiler:** Zig 0.15.2
**Memory:** 4 GB
**Storage:** 10 MB

### Build

```bash
zig build vsa-test
```

### Run

```bash
# 1. Test VSA operations
./zig-out/bin/vsa-test --all

# Expected:
# Test 1: Bind/Unbind... PASS
# Test 2: Bundle... PASS
# Test 3: Cosine Similarity... PASS
# Test 4: Permutation... PASS
# Test 5: Bitflip Resilience... PASS
#   FHRR: 30.1% tolerance
#   BSC: 10.2% tolerance
# All tests passed!
```

### Expected Results

| Operation | Scalar (ns) | SIMD (ns) | Speedup |
|-----------|-------------|-----------|---------|
| Bind | 45 | 3.2 | 14.2× |
| Bundle | 52 | 4.4 | 11.8× |
| Cosine | 68 | 4.0 | 17.2× |
| Permute | 38 | 2.8 | 13.6× |

---

## Cross-Bundle Reproducibility

### Docker Environment

**For complete reproduction:**

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    xz-utils \
    git \
    yosys \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Install Zig
RUN wget https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz && \
    tar xf zig-linux-x86_64-0.15.2.tar.xz && \
    mv zig-linux-x86_64-0.15.2 /usr/local/zig

ENV PATH="/usr/local/zig:${PATH}"

# Clone Trinity
WORKDIR /workspace
RUN git clone https://github.com/gHashTag/trinity .
RUN git checkout v1.0.0

# Build and test
RUN zig build
RUN zig build test

# Verify results
RUN echo "Build complete!" && \
    echo "Test results:" && \
    zig build test --summary all

CMD ["/bin/bash"]
```

**Build and run:**
```bash
docker build -t trinity:repro .
docker run -it trinity:repro
```

---

## Badge Criteria

### Artifacts Available Badge

- [ ] Code publicly available (GitHub)
- [ ] License specified (MIT)
- [ ] Version tagged (v1.0.0)
- [ ] README with setup instructions

### Artifacts Evaluated - Functional Badge

- [ ] Code compiles without errors
- [ ] Tests pass (2508/2508)
- [ ] Documentation complete
- [ ] Example runs successfully

### Artifacts Evaluated - Reusable Badge

- [ ] Complete build instructions
- [ ] All dependencies documented
- [ ] Troubleshooting guide
- [ ] Expected results specified
- [ ] Docker image available

### Results Reproduced Badge

- [ ] Metrics match paper (within tolerance)
- [ ] Multiple runs produce consistent results
- [ ] Random seeds specified
- [ ] Confidence intervals overlap

---

## Troubleshooting Guide

### Common Issues

| Issue | Bundle | Solution |
|-------|--------|----------|
| Zig not found | All | Install Zig 0.15.2 |
| Build fails | All | Check Zig version |
| Tests fail | All | Run `zig build test` first |
| FPGA errors | B002 | Check toolchain versions |
| Slow training | B001 | Reduce batch size |
| Out of memory | B001 | Use smaller checkpoint |
| VSA test fails | B007 | Check SIMD support |

### Debug Commands

```bash
# Verbose build
zig build -freference-trace

# Debug tests
zig build test --test-filter [test_name] --main-trace

# Check Zig version
zig version

# System info
uname -a
free -h
df -h
```

### Getting Help

- **GitHub Issues:** https://github.com/gHashTag/trinity/issues
- **Documentation:** https://github.com/gHashTag/trinity/tree/main/docs
- **Discussions:** https://github.com/gHashTag/trinity/discussions

---

## Summary Checklist

Before claiming reproducibility:

- [ ] Code compiles on fresh machine
- [ ] All tests pass
- [ ] Documentation is complete
- [ ] Dependencies are specified
- [ ] Random seeds are fixed
- [ ] Results are reproducible
- [ ] Docker image builds
- [ ] Expected output documented
- [ ] Troubleshooting guide exists
- [ ] Contact information provided

---

**φ² + 1/φ² = 3 | TRINITY**
