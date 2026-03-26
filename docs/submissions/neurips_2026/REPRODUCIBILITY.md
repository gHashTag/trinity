# NeurIPS 2026 Submission — Reproducibility

**Paper Title:** Trinity: A Ternary Neural Network Framework with Algebraically Structured Formats and Zero-DSP FPGA Deployment

**Anonymous Authors** *(double-blind submission)*

---

## Code Availability

### Repository Structure

**Anonymous GitHub:** [Link provided after acceptance]

**Repository Contents:**
```
trinity/
├── src/
│   ├── hslm/              # HSLM model implementation
│   ├── hslm/f16_utils.zig  # GF16/TF3 operations
│   ├── hslm/model.zig     # Model architecture
│   ├── hslm/trainer.zig   # Training loop
│   ├── vsa.zig            # VSA operations
│   └── tri27/             # TRI-27 interpreter
├── fpga/
│   └── openxc7-synth/     # Verilog implementations
│       ├── sacred_alu.v   # GF16/TF3 arithmetic
│       ├── ternary_mac.v  # Zero-DSP MAC
│       └── cordic.v       # φ-RoPE implementation
├── proofs/                # Coq/Lean4 formal proofs
├── tests/                 # Test suite
├── tools/                 # Benchmarking scripts
└── docs/                  # Documentation
```

### Build Instructions

**Dependencies:**
- Zig 0.15.x (https://ziglang.org/download)
- Yosys 0.38+ (https://github.com/YosysHQ/yosys)
- nextpnr-xilinx (https://github.com/openXC7/nextpnr-xilinx)
- OpenOCD (for FPGA programming)

**Building:**
```bash
# Clone repository
git clone [anonymous-anon-url]
cd trinity

# Build all binaries
zig build

# Run tests
zig test

# Build HSLM trainer
zig build hslm-train

# Build FPGA bitstream
cd fpga/openxc7-synth
make hslm_bitstream
```

---

## Data Availability

### Datasets

**TinyStories** [Eldan & Li, 2023]
- **Source:** https://huggingface.co/datasets/EldanLi/TinyStories
- **License:** MIT
- **Size:** 2M stories, 33M tokens
- **Usage:** Training and validation

**Preprocessing:**
- Tokenization: Character-level (unique characters in dataset)
- Train/validation split: 90%/10%
- No additional preprocessing required

### Generated Data

**Training Checkpoints:**
- Location: `data/checkpoints/`
- Format: TF3 packed ternary weights
- Size: 385 KB (HSLM v1.0)
- DOI: [Zenodo DOI provided after acceptance]

**Experimental Results:**
- Location: `data/results/`
- Format: CSV, JSON
- Contents: Loss curves, PPL measurements, resource utilization
- DOI: [Zenodo DOI provided after acceptance]

---

## Hyperparameters

### HSLM Model Architecture

| Parameter | Value | Description |
|-----------|-------|-------------|
| Vocabulary size | 729 | Powers of 3 (3⁶) |
| Embedding dim | 243 | Powers of 3 (3⁵) |
| Hidden dim | 729 | Powers of 3 (3⁶) |
| Layers | 3 | Transformer blocks |
| Heads | 3 | Attention heads |
| FFN expansion | φ² ≈ 2.618 | Golden ratio |
| Dropout | φ⁻² ≈ 0.382 | Sacred gamma |

### Training Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| Optimizer | AdamW | - |
| Learning rate | 3e-4 | Initial LR |
| Batch size | 64 | - |
| Steps | 30,000 | Total training steps |
| Warmup steps | 5,000 | LR warmup |
| LR schedule | Cosine | Cosine decay |
| Weight decay | 0.01 | L2 regularization |
| Gradient clip | 1.0 | Norm clipping |

### Quantization Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| TF3 threshold | 0.3 | Quantization threshold |
| GF16 mantissa | 9 bits | Significant figures |
| GF16 exponent | 6 bits | Dynamic range |
| STE clip | 1.0 | Straight-through estimator bound |

---

## Computational Requirements

### Training

**Hardware:** Apple M1 Max (8 performance cores, 32 GB RAM)

**Time:** ~6 hours for 30K steps

**Energy:** ~0.28 kWh

**Commands:**
```bash
zig build hslm-train
./zig-out/bin/hslm-train \
    --data data/tinystories/real_tinystories.txt \
    --steps 30000 \
    --lr 3e-4 \
    --batch 64 \
    --warmup 5000 \
    --schedule cosine \
    --checkpoint-dir data/checkpoints
```

### FPGA Synthesis

**Hardware:** Any workstation with 8 GB RAM

**Time:** ~45 seconds for HSLM synthesis

**Commands:**
```bash
cd fpga/openxc7-synth
yosys hslm.v -p "synth_xilinx" -o hslm_synth.v
nextpnr-xilinx --chip xc7a100t --json hslm_synth.json --write hslm_route.json
```

---

## Evaluation Metrics

### Perplexity

**Computation:**
```python
import numpy as np

def perplexity(loss):
    return np.exp(loss)
```

**Reporting:** Mean and standard deviation across 5 runs

### Resource Utilization

**Measurement:**
- Parse Yosys synthesis report
- Extract LUT, FF, DSP, BRAM counts
- Compute utilization vs available resources

**Commands:**
```bash
yosys hslm.v -p "synth_xilinx -stats hslm_stats.json"
python3 tools/parse_report.py hslm_stats.json
```

### Power Consumption

**Measurement:**
- Xilinx Power Estimator (XPE)
- Voltage: 1.0V
- Current: Measured via multimeter
- Power = Voltage × Current

**Reporting:** Dynamic + static power breakdown

---

## Random Seeds

**Seeds used:**
- Run 1: 42
- Run 2: 123
- Run 3: 456
- Run 4: 789
- Run 4: 314

**Setting seed:**
```bash
./zig-out/bin/hslm-train --seed 42 --data ...
```

---

## Statistical Significance

### Ablation Study

For each ablation (e.g., removing Consciousness Gate), we run 5 trials with different seeds and report mean ± standard deviation.

**Significance testing:** Two-tailed t-test comparing full model vs ablated variant, α=0.05.

### Bitflip Resilience

**Method:** Corrupt VSA vectors at random positions with given corruption percentage (10%, 20%, 30%).

**Metric:** Classification accuracy (or PPL retention) vs corruption level.

**Reporting:** Mean across 10 corruption trials per percentage level.

---

## Checklist for Reproducibility

### Code

- [x] Source code available (MIT license)
- [x] Build instructions provided
- [x] Dependencies listed with versions
- [x] Test suite included (>90% coverage)
- [x] Code comments for critical sections

### Data

- [x] Dataset publicly available (TinyStories)
- [x] Preprocessing steps documented
- [x] Train/validation splits specified
- [x] Checkpoints available (Zenodo DOI)

### Experiments

- [x] Hyperparameters fully specified
- [x] Random seeds documented
- [x] Computational requirements stated
- [x] Evaluation metrics defined
- [x] Statistical tests described

### Artifacts

- [x] FPGA bitstream available
- [x] Synthesis reports included
- [x] Power measurements documented
- [x] Formal proofs (Coq scripts)

### Documentation

- [x] README with quick start
- [x] API reference documentation
- [x] Tutorial notebooks provided
- [x] Known issues documented

---

## Docker Reproducibility

### Docker Image

**Image:** `trinity:neurips2026`

**Contents:**
- Ubuntu 22.04 base
- Zig 0.15.x compiler
- Yosys 0.38+ synthesis tool
- nextpnr-xilinx
- All Python dependencies
- TinyStories dataset

**Usage:**
```bash
docker pull trinity:neurips2026
docker run -it trinity:neurips2026

# Inside container
cd /workspace
zig build
zig test
./zig-out/bin/hslm-train --data data/tinystories --steps 1000
```

---

## Troubleshooting

### Common Issues

**Issue:** Zig build fails with "unknown instruction"
**Solution:** Ensure Zig 0.15.x is installed (`zig version`)

**Issue:** FPGA synthesis fails with "Yosys not found"
**Solution:** Install Yosys via `sudo apt-get install yosys` (Ubuntu) or build from source

**Issue:** Power measurement shows 0W
**Solution:** Ensure FPGA is configured and running inference, not idle

**Issue:** PPL differs from paper
**Solution:** Verify exact commit hash (`git rev-parse HEAD`) and dataset version

---

## Contact

**Issues:** Please report via GitHub Issues (anonymous link provided after acceptance)

**Email:** [Anonymous contact provided after acceptance]

---

**Document Control:** NEURIPS-REPRO-001
**Status:** Draft — Updated with final values before submission
