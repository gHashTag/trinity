# FPGA Verify Report Format

This document describes the output format of the `tri fpga verify` command and the LED detector.

## Overview

The FPGA verification system analyzes video of FPGA board LEDs to detect blink frequency and determine if the hardware behavior matches expected patterns.

## Command Usage

```bash
# Basic usage (detection only)
tri fpga verify <video_path>

# With expected frequency (for PASS/FAIL verdict)
tri fpga verify <video_path> --expected-freq <Hz>

# With custom threshold
tri fpga verify <video_path> --expected-freq <Hz> --threshold <0.0-1.0>

# Verbose output
tri fpga verify <video_path> --verbose
```

## JSON Output Format

```json
{
  "frequency_hz": 1.0,
  "confidence": 0.87,
  "verdict": "PASS",
  "pattern": "MEDIUM",
  "description": "Medium blink (~1.00 Hz)",
  "reason": "Frequency within tolerance: 1.00 Hz ≈ 1.00 Hz",
  "video_info": {
    "path": "/path/to/video.mp4",
    "resolution": "640x480",
    "fps": 30.0,
    "frames_analyzed": 300,
    "led_region": [295, 215, 51, 51]
  },
  "expected_hz": 1.0
}
```

## Output Fields

| Field | Type | Description |
|-------|------|-------------|
| `frequency_hz` | number | Detected blink frequency in Hz (0 = solid) |
| `confidence` | number | Confidence score 0-1 (higher = more certain) |
| `verdict` | string | `"PASS"` or `"FAIL"` |
| `pattern` | string | Pattern classification: SOLID, SLOW, MEDIUM, FAST, CHAOTIC, UNKNOWN |
| `description` | string | Human-readable description |
| `reason` | string | Detailed reason for verdict |
| `video_info` | object | Video metadata |
| `expected_hz` | number | Expected frequency (if specified) |

### Pattern Classification

| Pattern | Frequency Range | Description |
|---------|----------------|-------------|
| `SOLID` | 0 Hz | LED is solid ON or OFF (no blinking) |
| `SLOW` | < 1 Hz | Slow blink (~0.1-1 Hz) |
| `MEDIUM` | 1-5 Hz | Medium blink (~1-5 Hz) |
| `FAST` | 5-15 Hz | Fast blink (~5-15 Hz) |
| `CHAOTIC` | > 15 Hz | Rapid/chaotic pattern |
| `UNKNOWN` | any | Low confidence - cannot determine |

## Verdict Conditions

### PASS Conditions

1. **Detection only** (no `--expected-freq`):
   - `confidence >= threshold` (default: 0.3)

2. **With expected frequency**:
   - `confidence >= threshold`
   - `|detected_freq - expected_freq| <= expected_freq * tolerance` (default: 15%)

### FAIL Conditions

1. `confidence < threshold` - "Confidence too low"
2. Frequency out of tolerance - "Frequency out of tolerance"
3. SOLID expected but blinking detected - "Expected SOLID, detected X Hz"
4. Video file not found - error in JSON

## Thresholds

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--threshold` | 0.3 | Minimum confidence for PASS (0-1) |
| `--min-freq` | 0.1 Hz | Minimum frequency to detect |
| `--max-freq` | 15.0 Hz | Maximum frequency to detect |
| Tolerance | 15% | Frequency tolerance for PASS verdict |

## Examples

### Example 1: 1 Hz blink (PASS)

```bash
$ tri fpga verify golden_blink_1hz.mp4 --expected-freq 1.0
```

```json
{
  "frequency_hz": 1.0,
  "confidence": 0.87,
  "verdict": "PASS",
  "pattern": "MEDIUM",
  "description": "Medium blink (~1.00 Hz)",
  "reason": "Frequency within tolerance: 1.00 Hz ≈ 1.00 Hz",
  "expected_hz": 1.0
}
```

### Example 2: Wrong frequency (FAIL)

```bash
$ tri fpga verify video.mp4 --expected-freq 3.0
```

```json
{
  "frequency_hz": 1.5,
  "confidence": 0.65,
  "verdict": "FAIL",
  "pattern": "MEDIUM",
  "description": "Medium blink (~1.50 Hz)",
  "reason": "Frequency out of tolerance: 1.50 Hz vs 3.00 Hz (±0.45 Hz)",
  "expected_hz": 3.0
}
```

### Example 3: SOLID LED (PASS)

```bash
$ tri fpga verify solid.mp4 --expected-freq 0.0
```

```json
{
  "frequency_hz": 0.0,
  "confidence": 0.95,
  "verdict": "PASS",
  "pattern": "SOLID",
  "description": "LED is solid ON or OFF (no blinking detected)",
  "reason": "Solid state confirmed",
  "expected_hz": 0.0
}
```

## Algorithm

1. **APL Extraction**: Extract Average Pixel Level (APL) time series from video frames
2. **LED Region Detection**: Auto-detect LED region (brightest area)
3. **FFT Analysis**: Compute FFT to find dominant frequency
4. **Harmonic Detection**: Sum power across odd harmonics (square wave pattern)
5. **SNR Calculation**: Compute signal-to-noise ratio for confidence
6. **Pattern Classification**: Classify blink pattern based on frequency
7. **Verdict**: Compare detected frequency to expected (if specified)

## Regression Testing

Run automated regression tests:

```bash
cd fpga/tests/fpga
./verify_regression.sh
```

This tests the detector on synthetic golden samples with known frequencies:
- 1 Hz blink
- 3 Hz blink
- SOLID (0 Hz)

## Integration with TRI CLI

The LED detector is integrated into `tri fpga verify`:

```bash
# Flash and verify in one command
tri fpga flash verify blink.vibee

# Verify existing video
tri fpga verify /path/to/video.mp4
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Low confidence | Increase video duration, improve lighting |
| Wrong frequency | Check LED region selection, try `--led-region` |
| No video file | Check video path, ensure file exists |
| ImportError | Install dependencies: `pip install opencv-python numpy scipy` |
