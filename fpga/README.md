# Trinity FPGA Development

## Quick Start

```bash
# Synthesize Verilog → bitstream (openXC7 toolchain)
cd fpga/openxc7-synth
./synth.sh <design>.v <top_module>

# Flash to FPGA
../tools/jtag_program <design>.bit

# Visual verification with camera
cd ..
./test_with_camera.sh --design led_on
```

---

## Hardware

**FPGA Board**: QMTECH Artix-7 XC7A100T-1FGG676C

| Spec | Value |
|------|-------|
| FPGA | Artix-7 100T (101,440 logic cells) |
| Package | FGG676 (676-ball BGA) |
| Speed Grade | -1 (industrial) |
| Clock | 50 MHz oscillator on pin U22 |
| LEDs | Active-low on pins R23 (D6), T23 (D5) |

**JTAG Cable**: Xilinx Platform Cable USB II
- IDCODE: `0x13631093` (XC7A100T)
- VID:PID: `03fd:0013` → `03fd:0008` (after fxload firmware)

See [HARDWARE_REFERENCE.md](./HARDWARE_REFERENCE.md) for details.

---

## Toolchain Comparison

| Toolchain | Status | Notes |
|-----------|--------|-------|
| **openXC7** (Docker) | ✅ **WORKING** | Use this for production |
| **FORGE** (Zig) | ❌ BUGGY | 23 versions failed, experimental only |

**Recommendation**: Always use openXC7. FORGE has critical bugs in LUT INIT, FFMUX, and routing.

See [TOOLCHAIN_COMPARISON.md](./TOOLCHAIN_COMPARISON.md) for details.

---

## Synthesis Pipeline

### openXC7 Toolchain (Docker)

```bash
docker pull regymm/openxc7:latest  # 5.72 GB image

# Full pipeline: Verilog → JSON → FASM → frames → .bit
cd fpga/openxc7-synth
./synth.sh <design>.v <top_module>
```

**Pipeline steps**:
1. **Yosys**: Verilog → JSON netlist (synth_xilinx)
2. **nextpnr-xilinx**: Placement & routing → FASM
3. **fasm2frames**: FASM → configuration frames
4. **xc7frames2bit**: frames → .bit bitstream

---

## Programming (JTAG)

### One-time: Load Platform Cable Firmware

```bash
sudo fpga/tools/fxload \
  -v -t fx2 \
  -d 03fd:0013 \
  -i fpga/tools/xusb_xp2.hex
```

### Flash Bitstream

```bash
sudo fpga/tools/jtag_program <design>.bit
```

**Expected output**:
```
IDCODE: 0x13631093 (XC7A100T ✓)
Sending bitstream (3.6 MB)...
[████████████████████] 100%
FPGA programmed ✓
```

---

## Visual Testing (Camera)

**Link 23 of Golden Chain v4.2**: Automatic LED verification via iPhone camera.

```bash
# Full pipeline: build → flash → photo → evidence
./fpga/test_with_camera.sh --design led_on

# Photo only (board already programmed)
./fpga/test_with_camera.sh --photo-only

# Use Desk View camera (top-down)
./fpga/test_with_camera.sh --photo-only --device 3

# List available cameras
./fpga/test_with_camera.sh --list-cameras
```

See [VISION_TESTING.md](./VISION_TESTING.md) for details.

---

## Common Pitfalls

### Synthesis

❌ **Wrong top module name** - Must match .v file
```verilog
module temporal_heartbeat_top (  // <-- This name
    input wire clk,
    output wire led
);
```
```bash
./synth.sh temporal_heartbeat.v temporal_heartbeat_top  # <-- Match!
```

❌ **Wrong XDC file** - Use `trinity.xdc` for QMTECH board
- `qmtech_fgg676.xdc` → Wrong pins!
- `trinity.xdc` → Correct (U22=clk, T23=led)

❌ **Using FORGE** - Use openXC7 instead
```bash
# WRONG (buggy):
zig build forge
./forge run ...

# CORRECT:
cd fpga/openxc7-synth
./synth.sh design.v top
```

### Programming

❌ **Forgetting fxload** - Run once per session
❌ **Wrong JTAG cable** - Must be Platform Cable USB II (03fd:0013)

### Verification

❌ **Single photo for blinking LED** - Cannot detect >1 Hz
✅ Use video capture (3-5 sec @ 30fps)

❌ **Vision API file:// URLs** - Not supported
✅ Upload to 0x0.st or use HTTP URL

See [COMMON_PITFALLS.md](./COMMON_PITFALLS.md) for complete list.

---

## Evidence & Documentation

### Evidence Folder

Test photos and metadata are saved to `fpga/evidence/`:

```
fpga/evidence/
├── README.md                    # Format specification
├── led_on_forge_fix_20260304.jpg
├── led_on_forge_fix_closeup_20260304.jpg
└── led_on_forge_fix_20260304.txt    # Metadata
```

### Documentation Files

| File | Purpose |
|------|---------|
| [ITERATION_LOG.md](./ITERATION_LOG.md) | Session history & results |
| [VISION_TESTING.md](./VISION_TESTING.md) | Camera verification guide |
| [TOOLCHAIN_COMPARISON.md](./TOOLCHAIN_COMPARISON.md) | openXC7 vs FORGE |
| [HARDWARE_REFERENCE.md](./HARDWARE_REFERENCE.md) | QMTECH board details |
| [COMMON_PITFALLS.md](./COMMON_PITFALLS.md) | Lessons learned |

### Historical Documentation

From previous sessions (in `fpga/openxc7-synth/`):
- `FORGE_SESSION_RULES.md` - Critical lessons from v18-v23 failures
- `OPENXC7_SUCCESS_REPORT.md` - Temporal heartbeat success report
- `ROUTING_DEEP_DIVE.md` - FPGA architecture analysis

---

## Directory Structure

```
fpga/
├── README.md                      # This file
├── ITERATION_LOG.md               # Session history
├── VISION_TESTING.md              # Camera testing guide
├── TOOLCHAIN_COMPARISON.md        # Toolchain comparison
├── HARDWARE_REFERENCE.md          # Board reference
├── COMMON_PITFALLS.md             # Lessons learned
├── test_with_camera.sh            # Full vision pipeline
├── evidence/                      # Test photos + metadata
│   └── README.md
├── tools/                         # Programming tools
│   ├── jtag_program               # JTAG programmer
│   ├── fxload                     # Firmware loader
│   └── cam_snapshot.sh            # Photo capture
└── openxc7-synth/                 # Synthesis workspace
    ├── synth.sh                   # Build script
    ├── *.v                        # Verilog sources
    ├── *.xdc                      # Constraint files
    ├── *.bit                      # Bitstreams
    └── *.md                       # Historical docs
```

---

## Integration with Trinity

**Golden Chain v4.2 Link 23**: `VISION_LED_TEST`

Module: `src/tri/vision_led_test.zig`

Environment variable:
```bash
export TRI_CAMERA_URL="http://192.168.1.100:8080/photo.jpg"
```

Execution:
```bash
tri pipeline run "test LED D6 blinking"
# ... Link 23 will capture and analyze photo
```

---

## φ² + 1/φ² = 3 = TRINITY
