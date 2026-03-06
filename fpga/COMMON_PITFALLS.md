# Common FPGA Development Pitfalls

Lessons learned from hard experience to help other agents avoid repeating mistakes.

---

## Synthesis Pitfalls

### ❌ Wrong Top Module Name

**Problem**: Module name in Verilog doesn't match build parameter.

```verilog
// d6_blink.v
module trinity_top (  // <-- This is the module name
    input wire clk,
    output wire led
);
```

```bash
# Build command expects d6_blink_top
./synth.sh d6_blink.v d6_blink_top  # ❌ MISMATCH!
```

**Result**: Synthesis fails or generates wrong bitstream.

**Solution**:
```bash
# Option 1: Match the module name
./synth.sh d6_blink.v trinity_top

# Option 2: Fix Verilog to match expected name
module d6_blink_top (
    input wire clk,
    output wire led
);
```

**Rule**: Always verify module name matches build parameter.

---

### ❌ Wrong XDC File

**Problem**: Using incorrect constraint file for QMTECH board.

| File | LEDs | Status |
|------|------|--------|
| `qmtech_fgg676.xdc` | Wrong pins | ❌ Don't use |
| `trinity.xdc` | U22=clk, T23=led | ✅ Correct |
| `d6_blink.xdc` | U22=clk, R23=led | ✅ Correct |

**Result**: Bitstream programs but LEDs don't work.

**Solution**: Always use correct XDC for your design.
- For T23 (D5): Use `trinity.xdc`
- For R23 (D6): Use `d6_blink.xdc`

---

### ❌ Using FORGE for Production

**Problem**: FORGE has 0% success rate (23 failed versions).

| Toolchain | Success Rate | Status |
|-----------|--------------|--------|
| openXC7 | 100% (1/1) | ✅ Working |
| FORGE | 0% (0/23) | ❌ Buggy |

**Known bugs**:
- LUT INIT truth tables wrong
- FFMUX strategy incorrect
- VCC IMUX override bug
- Missing OLOGIC features

**Solution**: Always use openXC7 for production work.

```bash
# CORRECT
cd fpga/openxc7-synth
./synth.sh design.v top

# WRONG (FORGE is experimental)
zig build forge
./forge run ...
```

---

### ❌ Active-Low Confusion

**Problem**: QMTECH LEDs are active-low but logic assumes active-high.

```verilog
// WRONG: Assumes active-high
assign led = blink_state;  // 1 = ON, 0 = OFF

// CORRECT: Active-low
assign led = ~blink_state;  // 0 = ON, 1 = OFF
```

**Result**: LED behavior inverted (ON when should be OFF).

**Solution**: Remember QMTECH LEDs are **active-low**:
- LED ON = logic 0
- LED OFF = logic 1

---

## Programming Pitfalls

### ❌ Forgetting fxload (EVERY SESSION!)

**Problem**: Platform Cable USB II boots in bootloader mode EVERY TIME it's power-cycled or replugged.

```bash
# Without fxload - cable in wrong mode
sudo ./jtag_program design.bit
# Error: unable to open ftdi device
# OR: libusb_control_transfer(0x28.x)Failed to connect
```

**Solution**: Load firmware ONCE PER SESSION, then replug.

```bash
# Step 1: Load firmware (cable → PID 0013)
sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex
# Expected: "WROTE: 7962 bytes, 90 segments, avg 88"

# Step 2: Replug cable USB (cable → PID 0008)
# UNPLUG and REPLUG the cable now!

# Step 3: Flash (now works)
sudo ./jtag_program design.bit
```

**Check mode**: `ioreg -p IOUSB -w0 -l | grep -A 5 "XILINX"`
- Bootloader: `"idProduct" = 13`
- JTAG mode: `"idProduct" = 8` ✓

**⚠️ REMEMBER: fxload + replug EVERY TIME!**

---

### ❌ Wrong JTAG Cable

**Problem**: Using FTDI-based cable instead of Platform Cable.

| Cable | VID:PID | Supported |
|-------|---------|-----------|
| Platform Cable USB II | 03fd:0008 | ✅ Yes |
| FTDI generic | 0403:6010 | ❌ No |

**Solution**: Use Xilinx Platform Cable USB II or openFPGALoader for FTDI cables.

---

### ❌ Interrupting Programming

**Problem**: Stopping jtag_program mid-stream.

```bash
sudo ./jtag_program design.bit
# 50%... ^C (user interrupt)
```

**Result**: FPGA in undefined state (partial configuration).

**Solution**: Always let programming complete. Takes ~60 seconds for 3.6 MB.

---

## Verification Pitfalls

### ❌ Single Photo for Blinking LED

**Problem**: Single photo captures one instant (LED either ON or OFF).

**For 3 Hz blinking**:
- Photo 1: LED OFF
- Photo 2: LED ON
- Photo 3: LED OFF
- ...

**Result**: Can't determine if LED is actually blinking.

**Solution**: Use video capture (3-5 seconds @ 30fps).

```bash
# Capture video
ffmpeg -f avfoundation -i "2:none" -t 3 \
    /tmp/led_test.mp4

# Analyze frames for brightness changes
```

---

### ❌ Vision API file:// URLs

**Problem**: MCP Vision API doesn't support local file URLs.

```bash
# WRONG - file:// URL
mcp__4_5v_mcp__analyze_image("file:///tmp/board.jpg")
# Error: 图片输入格式/解析错误
```

**Solution**: Upload to 0x0.st for HTTP URL.

```bash
# Upload photo
URL=$(curl -s -F "file=@/tmp/board.jpg" https://0x0.st)

# Analyze via HTTP
mcp__4_5v_mcp__analyze_image("$URL")
```

---

### ❌ Camera Exposure Integration

**Problem**: Fast blinking LED appears always ON due to exposure.

**For 3 Hz blink (167ms ON, 167ms OFF)**:
- 30fps frame = 33ms exposure
- LED ON during most of exposure
- Result: Bright LED in every frame

**Solution**: Use faster shutter or photodiode.

---

## Design Pitfalls

### ❌ Missing Reset Logic

**Problem**: FPGA starts in unknown state.

```verilog
// WRONG - No reset
reg [24:0] counter;
always @(posedge clk) begin
    counter <= counter + 1;  // What is initial value?
end

// CORRECT - With reset
reg [24:0] counter;
always @(posedge clk) begin
    if (reset)
        counter <= 25'd0;
    else
        counter <= counter + 1;
end
```

**Solution**: Always include reset logic.

---

### ❌ Clock Domain Issues

**Problem**: Using divided clock instead of clock enable.

```verilog
// WRONG - Divided clock
reg clk_div;
always @(posedge clk) begin
    clk_div <= ~clk_div;  // Glitchy!
end

// CORRECT - Clock enable
reg [24:0] counter;
wire tick = (counter == 25'd0);
always @(posedge clk) begin
    if (tick) begin
        // Do something
    end
end
```

**Solution**: Use single clock domain with enables.

---

### ❌ Inferred Latches

**Problem**: Incomplete if-else creates latches.

```verilog
// WRONG - Creates latch
always @(*) begin
    if (condition)
        result = input_a;
    // Missing else -> latch!
end

// CORRECT - No latch
always @(*) begin
    if (condition)
        result = input_a;
    else
        result = 25'd0;  // Default case
end
```

**Solution**: Always provide default cases.

---

## nextpnr-xilinx Specific Bugs

### ❌ R23 Pin Incorrectly Mapped to IOB_Y1

**Problem**: nextpnr-xilinx incorrectly maps R23 to IOB_Y1 (T23) instead of IOB_Y0.

**Symptoms**:
- XDC specifies `LOC R23` (D6)
- FASM shows `IOB_Y1` (T23/D5) instead of `IOB_Y0` (R23/D6)
- LED on wrong pin lights up

**Root Cause**: Chip database or nextpnr routing bug for QMTECH XC7A100T.

```
XDC file: LOC R23  →  nextpnr places on IOB_Y1 (T23) ❌
XDC file: LOC T23  →  nextpnr places on IOB_Y1 (T23) ✅
```

**Workaround**: Use T23 (D5) as primary LED since it maps correctly.

```
# Use this XDC for reliable LED operation
set_property LOC T23 [get_ports led]   # Works correctly
set_property LOC U22 [get_ports clk]   # Clock (no issues)
```

**Impact**: Cannot use R23 (D6) for designs. Must use T23 (D5) as LED output.

**Reported**: nextpnr-xilinx issue, needs investigation of chipdb.

---

## Debugging Pitfalls

### ❌ Trusting Simulation Blindly

**Problem**: Simulation passes but hardware fails.

**Reasons**:
- Timing issues not modeled
- Clock domain crossing not checked
- FPGA-specific primitives not simulated

**Solution**: Always test on real hardware.

---

### ❌ Ignoring Warnings

**Problem**: Warnings indicate real issues.

```
WARNING: Port 'clk' has no driver
WARNING: LUT primitive has no output
WARNING: Timing violation not met
```

**Result**: Bitstream works incorrectly.

**Solution**: Fix all warnings before programming.

---

## Quick Checklist

Before flashing a bitstream:

- [ ] Module name matches build parameter?
- [ ] Correct XDC file for target pins?
- [ ] Using openXC7 (not FORGE)?
- [ ] Active-low logic accounted for?
- [ ] fxload run for Platform Cable?
- [ ] JTAG IDCODE correct (0x13631093)?
- [ ] Synthesis warnings reviewed?
- [ ] Reset logic included?
- [ ] Test on hardware planned?

---

## φ² + 1/φ² = 3 = TRINITY
