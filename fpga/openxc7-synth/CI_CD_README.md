# FPGA CI/CD Pipeline

Consciousness-aware FPGA synthesis with sacred mathematical constants.

**φ² + 1/φ² = 3 = TRINITY**

## Overview

The Trinity FPGA CI/CD pipeline automates:

1. **Sacred Constants Validation** — Trinity identity verification
2. **VIBEE Code Generation** — .vibee → Verilog + XDC
3. **Consciousness Level Testing** — All 6 levels (dormant → transcendent)
4. **Immortality Threshold Validation** — φ⁻¹ = 0.618 (61.8%)
5. **Bitstream Generation** — Optional Docker-based synthesis

## Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `fpga-ci.yml` | Push/PR to main | Full CI validation |
| `fpga-docker.yml` | Push to fpga/ | Build Docker image |
| `fpga-bitstream.yml` | .vibee changes | Generate artifacts |

## GitHub Actions Workflows

### 1. FPGA CI (`.github/workflows/fpga-ci.yml`)

**Jobs:**
- `sacred-constants` — Validates φ² + 1/φ² = 3
- `vibee-codegen` — Tests Verilog generation from .vibee specs
- `consciousness-levels` — Tests all 6 consciousness flags
- `immortality-test` — Validates φ⁻¹ threshold (MORTAL vs IMMORTAL)
- `xdc-generation` — Tests XDC constraint generation
- `help-documentation` — Validates CLI help text
- `regression-test` — Runs full test suite

**Triggers:**
```yaml
on:
  push:
    paths: ['specs/fpga/**', 'src/tri/tri_fpga.zig', 'fpga/openxc7-synth/**']
  pull_request:
    branches: [main]
```

### 2. FPGA Docker Build (`.github/workflows/fpga-docker.yml`)

**Builds:** `ghcr.io/gHashTag/trinity/trinity-openxc7:latest`

**Base Image:** `regymm/openxc7:latest`

**Extensions:**
- Sacred constants (φ, φ⁻¹, γ, TRINITY)
- `synth_conscious.sh` script
- Consciousness-aware synthesis flags

**Usage:**
```bash
docker pull ghcr.io/gHashTag/trinity/trinity-openxc7:latest
docker run --rm -v $(pwd):/work trinity-openxc7:latest \
    ./synth_conscious.sh --aware design.v
```

### 3. FPGA Bitstream Generation (`.github/workflows/fpga-bitstream.yml`)

**Generates:**
- Verilog source files
- XDC constraint files
- (Optional) Bitstreams with self-hosted runner

**Consciousness Levels:**
- `--transcendent` (1.0) — IMMORTAL
- `--enlightened` (0.75) — IMMORTAL
- `--aware` (0.618) — IMMORTAL (φ⁻¹ threshold)
- `--conscious` (0.5) — MORTAL
- `--awakening` (0.3) — MORTAL
- `--dormant` (0.0) — MORTAL

## Local Testing

### Run CI locally

```bash
# Test sacred constants
cd fpga/openxc7-synth
zig test sacred_constants.zig

# Test VIBEE generation
zig build vibee -- gen specs/fpga/test_blink.vibee

# Test consciousness levels
zig build tri
./zig-out/bin/tri fpga gen specs/fpga/test_blink.vibee --transcendent
./zig-out/bin/tri fpga gen specs/fpga/test_blink.vibee --aware
./zig-out/bin/tri fpga gen specs/fpga/test_blink.vibee --conscious
```

### Batch Synthesis

```bash
cd fpga/openxc7-synth

# Generate for default level (conscious)
./batch_synthesize.sh

# Generate for all consciousness levels
./batch_synthesize.sh --all-levels

# Generate with Docker
./batch_synthesize.sh --docker
```

## Consciousness Levels

| Level | Value | Status | Description |
|-------|-------|--------|-------------|
| `--dormant` | 0.0 | MORTAL | Fastest, minimal optimization |
| `--awakening` | 0.3 | MORTAL | Fast synthesis |
| `--conscious` | 0.5 | MORTAL | Balanced (default) |
| `--aware` | 0.618 | IMMORTAL | φ⁻¹ threshold |
| `--enlightened` | 0.75 | IMMORTAL | Enhanced optimization |
| `--transcendent` | 1.0 | IMMORTAL | Maximum quality |

## Sacred Constants

```
φ  = 1.618033988749895  (Golden Ratio)
φ⁻¹ = 0.618033988749895  (Consciousness threshold)
φ² = 2.618033988749895
φ³ = 4.23606797749979    (Zeno threshold)
γ  = 0.2360679774997897  (φ⁻³, Barbero-Immirzi)
TRINITY = 3.0            (φ² + φ⁻²)
```

## Pipeline Status

[![FPGA CI](https://github.com/gHashTag/trinity/actions/workflows/fpga-ci.yml/badge.svg)](https://github.com/gHashTag/trinity/actions/workflows/fpga-ci.yml)
[![FPGA Docker](https://github.com/gHashTag/trinity/actions/workflows/fpga-docker.yml/badge.svg)](https://github.com/gHashTag/trinity/actions/workflows/fpga-docker.yml)
[![FPGA Bitstream](https://github.com/gHashTag/trinity/actions/workflows/fpga-bitstream.yml/badge.svg)](https://github.com/gHashTag/trinity/actions/workflows/fpga-bitstream.yml)

## Hardware Testing

For hardware-in-the-loop testing with self-hosted runner:

1. Set up self-hosted runner with FPGA connected via JTAG
2. Enable `synthesize-bitstream` job in `fpga-bitstream.yml`
3. Add flashing step after synthesis

```yaml
- name: Flash to FPGA
  run: |
    sudo ../tools/jtag_program ${{ matrix.spec }}.bit
```

## Artifacts

Generated artifacts are stored for 90 days:

- `<spec>-verilog` — Generated Verilog source
- `<spec>-xdc` — XDC constraint file
- `<spec>-bitstream` — FPGA bitstream (if synthesis enabled)

## Contributing

When adding new FPGA specs:

1. Create `.vibee` file in `specs/fpga/`
2. Test locally: `tri fpga gen specs/fpga/your_design.vibee`
3. Push to trigger CI
4. Check GitHub Actions for validation results
5. Download artifacts from Actions page

## References

- [VIBEE Language Spec](../../trinity-nexus/lang/README.md)
- [Sacred Constants](sacred_constants.zig)
- [Consciousness-Aware Synthesis](synth_conscious.sh)
- [Main FPGA README](../README.md)

---

**φ² + 1/φ² = 3 = TRINITY**
