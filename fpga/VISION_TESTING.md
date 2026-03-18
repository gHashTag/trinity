# Vision-Based LED Testing

**Link 23 of Golden Chain v4.2**: Automatic LED verification via camera.

---

## Overview

The vision testing pipeline captures photos of the FPGA board to verify LED behavior:

```
Flash Bitstream → Wait for init → Capture Photo → Analyze → Save Evidence
```

### Use Cases

| Test | Expected Behavior |
|------|-------------------|
| LED ON | Single LED lit continuously |
| LED OFF | All LEDs dark |
| LED Blinking | LED toggles ON/OFF at specified frequency |

---

## Pipeline Tools

### 1. test_with_camera.sh - Full Pipeline

```bash
# Full cycle: build → flash → photo → evidence
./fpga/test_with_camera.sh --design led_on

# Photo only (board already programmed)
./fpga/test_with_camera.sh --photo-only

# Use different camera (Desk View)
./fpga/test_with_camera.sh --photo-only --device 3

# Longer autofocus time
./fpga/test_with_camera.sh --photo-only --duration 5

# List available cameras
./fpga/test_with_camera.sh --list-cameras
```

### 2. cam_snapshot.sh - Photo Capture

```bash
# Capture with default settings
./fpga/tools/cam_snapshot.sh /tmp/board.jpg

# Specify camera device
CAM_DEVICE=3 ./fpga/tools/cam_snapshot.sh /tmp/board.jpg

# Longer video for autofocus
CAM_DURATION=5 ./fpga/tools/cam_snapshot.sh /tmp/board.jpg
```

**Process**:
1. Records 3-second video (for autofocus)
2. Extracts last frame as photo
3. Returns photo path

---

## Hardware Requirements

### Camera Options

| Method | Device ID | Notes |
|--------|-----------|-------|
| iPhone Main | 2 | Default, best quality |
| iPhone Telephoto | 1 | Zoom, may be darker |
| Desk View (iPhone) | 3 | Top-down view |
| FaceTime HD | 0 | Built-in Mac camera |

### Setup

1. **Connect iPhone** via USB cable
2. **Trust Mac** when prompted on iPhone
3. **Enable Continuity Camera** in System Settings
4. **Position camera** pointing at FPGA board

---

## Integration with Golden Chain

### Link 23: VISION_LED_TEST

**Module**: `src/tri/vision_led_test.zig`

**Configuration**:
```zig
const config = VisionLedConfig{
    .led_name = "D6",
    .expected_behavior = .blinking,
    .expected_frequency = 3.0,
};
```

**Environment Variable**:
```bash
export TRI_CAMERA_URL="http://192.168.1.100:8080/photo.jpg"
```

**Execution**:
```bash
tri pipeline run "test LED D6 blinking"
```

---

## Limitations & Issues

### 1. Single Photo Cannot Detect Blinking

A single photo captures only one instant (LED either ON or OFF).

**For blinking LEDs (>1 Hz)**:
| Method | Pros | Cons |
|--------|------|------|
| Video analysis | Captures full cycle | More processing |
| Photodiode | Precise | Hardware required |
| Human observation | Simple | Subjective |

**Recommendation**: Capture 3-5 seconds of video at 30fps.

### 2. Vision API Inconsistency

The MCP Vision API sometimes returns contradictory results:
- Same photo analyzed twice → different results
- Confused by reflections or background
- file:// URLs not supported

**Workaround**: Upload to 0x0.st for HTTP URL access.

### 3. Camera Exposure Issues

Fast blinking may be "washed out" by auto-exposure:
- LED appears always ON (exposure integrates over frame time)
- LED appears always OFF (exposure too short)

**Solution**: Manual exposure settings if possible.

---

## Analysis Methods

### Method 1: Pixel Brightness (Local)

```bash
# Capture multiple frames
for i in {1..10}; do
    ffmpeg -f avfoundation -i "2:none" -frames:v 1 \
        /tmp/frame_$i.jpg
    sleep 0.5
done

# Analyze brightness (Python/CLI)
python3 << 'EOF'
# Read RGB values at LED position
# Calculate brightness: (R+G+B)/3
# Detect ON/OFF transitions
EOF
```

### Method 2: Vision API

```bash
# Upload photo
curl -F "file=@/tmp/board.jpg" https://0x0.st

# Analyze via MCP Vision API
# (See mcp__4_5v_mcp__analyze_image tool)
```

### Method 3: Human Verification

Simply look at the board and confirm:
- Which LEDs are lit
- Blinking pattern (if any)
- Any unexpected behavior

Document results in `fpga/evidence/*.txt`.

---

## Evidence Format

### Photo Naming

```
<design>_<variant>_<timestamp>.jpg
```

Examples:
- `led_on_forge_fix_20260304.jpg`
- `d6_blink_closeup_20260304.jpg`

### Metadata Format

See `fpga/evidence/README.md` for template.

```text
FPGA Visual Test Evidence
=========================
Date:       2026-03-04 14:29:00
Design:     led_on
Board:      QMTECH Artix-7 XC7A100T-1FGG676C
Camera:     Device [2] (iPhone Continuity Camera)
Photo:      led_on_forge_fix_20260304.jpg
Git commit: abc1234

Expected:
  - LED D6 should be ON
  - All other LEDs OFF

Actual:
  - LED D6: ON ✓
  - LED D5: OFF ✓
  - Other LEDs: OFF ✓

Result: PASS
```

---

## Troubleshooting

### Camera not detected

```bash
# List available cameras
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep "\[[0-9]\]"
```

### Photo is dark/blurry

```bash
# Increase autofocus time
CAM_DURATION=5 ./fpga/tools/cam_snapshot.sh /tmp/board.jpg
```

### Wrong camera being used

```bash
# Specify device explicitly
CAM_DEVICE=3 ./fpga/tools/cam_snapshot.sh /tmp/board.jpg
```

---

## Future Improvements

1. **Automated video analysis**
   - Detect ON/OFF transitions frame-by-frame
   - Calculate actual blink frequency

2. **Photodiode integration**
   - Hardware sensor for precise detection
   - Works with any blink frequency

3. **OpenCV-based detection**
   - Local image processing
   - No API dependency

4. **Automated regression testing**
   - Test suite runs after each build
   - Compares against reference images

---

## φ² + 1/φ² = 3 = TRINITY
