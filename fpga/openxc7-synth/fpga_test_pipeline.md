# FPGA Test Pipeline with Video Monitoring

## Overview

Automated testing pipeline for TRINITY FPGA bitstreams with LED pattern verification via video analysis.

## Hardware

- **FPGA:** QMTECH Artix-7 XC7A100T-1FGG676C
- **JTAG:** Xilinx Platform Cable USB II
- **LEDs:** D5 (T23), D6 (R23) — active LOW
- **Button:** SW1 (H19) — reset/mode change
- **Clock:** 50 MHz @ U22

## Flash Command

```bash
/Users/playra/trinity-w1/fpga/tools/jtag_program <bitstream>.bit
```

## Bitstreams & Expected LED Patterns

| Bitstream | Expected LED Pattern | Frequency | Description |
|-----------|---------------------|-----------|-------------|
| `temporal_heartbeat.bit` | Steady blink | ~3 Hz | Baseline test |
| `d6_blink.bit` | Steady blink (D5, not D6) | ~3 Hz | XDC bug — wrong pin |
| `ternary_dot.bit` | Pattern based on dot product | Variable | +/0/- modes |
| `vsa_quantum_top.bit` | Chaotic blink | Random/Chaotic | CGLMP violation mode |
| `trinity_v1.bit` | Multiple modes (SW1 to change) | Variable | Full TRINITY system |

### TRINITY V1 Modes (press SW1 to cycle)

| Mode | LED Pattern | Meaning |
|------|-------------|---------|
| 0 | Fast blink (~8-10 Hz) | Idle/Ready |
| 1 | Medium blink (~3 Hz) | Processing |
| 2 | Slow blink (~1 Hz) | VSA computation |
| 3 | Chaotic | Quantum violation |
| 4 | Solid ON | Error/Debug |

## Pipeline Steps

```bash
# 1. Flash bitstream
/Users/playra/trinity-w1/fpga/tools/jtag_program <name>.bit

# 2. Wait for initialization
sleep 2

# 3. Record video (15 seconds)
# Point phone at FPGA LEDs

# 4. Analyze video to detect LED pattern
python3 fpga/tools/led_pattern_analyzer.py video.mp4

# 5. Verify expected vs actual pattern
# 6. Document results
```

## Video Analysis

The LED pattern analyzer:
- Detects LED regions in frame
- Measures blink frequency
- Classifies pattern (steady/fast/slow/chaotic)
- Compares against expected pattern

## Phone Setup

### Option 1: QuickTime (macOS)

```bash
# Connect iPhone via USB
# Open QuickTime → File → New Movie Recording → Select iPhone
# Record FPGA LEDs for 15 seconds
# Save as test_<bitstream>.mov
```

### Option 2: Android (scrcpy)

```bash
brew install scrcpy
scrcpy --record=test.mp4
```

### Option 3: Web-based

1. Host simple video capture page
2. Access from phone
3. Upload recorded video
4. Analyze with image processing

## Results Logging

Results stored in: `fpga/test_results/<timestamp>/`

```
test_results/
├── 2026-03-06_120000/
│   ├── temporal_heartbeat/
│   │   ├── video.mp4
│   │   ├── analysis.json
│   │   └── result.txt
│   ├── ternary_dot/
│   └── trinity_v1/
```
