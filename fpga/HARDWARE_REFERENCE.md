# QMTECH Artix-7 XC7A100T Reference

## Board Specifications

| Parameter | Value |
|-----------|-------|
| **Model** | XC7A100T-1FGG676C |
| **FPGA** | Artix-7 100T |
| **Package** | FGG676 (676-ball BGA) |
| **Speed Grade** | -1 (industrial) |
| **Logic Cells** | 101,440 |
| **DSP Slices** | 240 |
| **BRAM** | 4.9 Mb |
| **User I/O** | 400+ |
| **Operating Temp** | 0°C to +85°C |

---

## Pin Mapping

### Clock Input

| Signal | Pin | Location | Notes |
|--------|-----|----------|-------|
| CLK_50MHz | U22 | Near edge | 50 MHz oscillator |

### LED Outputs (Active-Low)

| LED | Pin | Location | Notes |
|-----|-----|----------|-------|
| D6 | R23 | Bottom row | Primary test LED |
| D5 | T23 | Bottom row | Secondary test LED |

**Important**: LEDs are **active-low**:
- LED ON = 0 (logic low)
- LED OFF = 1 (logic high)

### XDC Constraints

```tcl
# Clock input (50 MHz oscillator)
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# LED D6 output
set_property LOC R23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
```

---

## JTAG Interface

### Cable

**Model**: Xilinx Platform Cable USB II

| State | VID | PID | Description |
|-------|-----|-----|-------------|
| Bootloader | 0x03fd | 0x0013 | Firmware not loaded |
| JTAG Mode | 0x03fd | 0x0008 | Ready for programming |

### FPGA IDCODE

```
IDCODE: 0x13631093
```

Breakdown:
- Bits [31:28]: 0x1 (Version)
- Bits [27:12]: 0x363 (Manufacturer: Xilinx)
- Bits [11:0]: 0x093 (Device: XC7A100T)

### JTAG Chain

```
Host → Platform Cable → FPGA (XC7A100T)
```

Single device chain (no Daisy-chain).

---

## Power Requirements

| Rail | Voltage | Current | Notes |
|------|---------|---------|-------|
| VCCINT | 1.0V | ~500mA | Core logic |
| VCCAUX | 1.8V | ~100mA | Auxiliary |
| VCCO_0 | 3.3V | ~10mA | Bank 0 (JTAG) |
| VCCO_14/15 | 3.3V | ~50mA | LED banks |

**Total Power**: ~2W max

### Power Supply

Use QMTECH supplied power adapter:
- Input: 100-240V AC, 50-60Hz
- Output: 5V DC, 2A

---

## Clocking

### Primary Clock

- **Source**: On-board 50 MHz oscillator
- **Pin**: U22
- **Accuracy**: ±50 ppm
- **Duty Cycle**: 50%

### Global Clock Network

Artix-7 has 32 global clock lines (BUFG):

```
OSC_50MHz (U22) → IBUF → BUFG → Clock Network
```

### Clock Constraints (XDC)

```tcl
# Create primary clock
create_clock -period 20.000 -name clk_50MHz [get_ports clk]

# Input delay
set_input_delay -clock clk_50MHz -max 2.0 [get_ports clk]

# Output delay (for LEDs)
set_output_delay -clock clk_50MHz -max 5.0 [get_ports led]
```

---

## IO Banks

### Bank 14 (Bottom)

- **VCCO**: 3.3V
- **Pins**: Include R23 (LED D6)
- **Standard**: LVCMOS33

### Bank 15 (Bottom)

- **VCCO**: 3.3V
- **Pins**: Include T23 (LED D5)
- **Standard**: LVCMOS33

### Bank 0 (JTAG)

- **VCCO**: 3.3V
- **Pins**: JTAG signals
- **Standard**: LVCMOS33

---

## LED Configuration

### Electrical Characteristics

| Parameter | Value |
|-----------|-------|
| Type | Active-low SMD LED |
| Forward Voltage | 2.0V (typ) |
| Forward Current | 2-5 mA |
| Series Resistor | ~330Ω (on-board) |

### IOB Configuration (from FASM)

```
LIOB33_X0Y51.IOB_Y0.LVCMOS33_LVTTL.DRIVE.I12_I8
LIOB33_X0Y51.IOB_Y0.LVCMOS12_LVCMOS15_LVCMOS18_LVCMOS25_LVCMOS33_LVTTL_SSTL135_SSTL15.SLEW.SLOW
LIOB33_X0Y51.IOB_Y0.PULLTYPE.NONE
```

### Drive Strength

- I12_I8 = 8 mA drive
- SLEW.SLOW = Slow slew rate (reduces EMI)

---

## Configuration

### Configuration Modes

| Mode | Pins | Notes |
|------|------|-------|
| JTAG | TMS, TCK, TDI, TDO | **Primary method** |
| SPI | FCS, CLK, MOSI, MISO | Requires slave serial |
| SelectMAP | D[0:15], CS, WR, etc. | Parallel interface |

### Bitstream Format

```
Sync Word (0xAA995566) → Packet Header → Data → ECC → ...
```

**Size**: ~3.6 MB for typical design

### Configuration Time

- JTAG: ~30-60 seconds (via Platform Cable)
- Slave Serial: ~50ms

---

## Physical Layout

```
┌─────────────────────────────────────────────┐
│         QMTECH XC7A100T-1FGG676C            │
│                                             │
│  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐       │
│  │ LED │  │ LED │  │ FPGA    │     │       │
│  │ D6  │  │ D5  │  │  XC7   │OSC  │       │
│  │R23  │  │T23  │  │ 100T   │U22  │       │
│  └─────┘  └─────┘  └─────┘  └─────┘       │
│                                             │
│  ┌─────────────────────────────────┐       │
│  │     JTAG Header (6-pin)          │       │
│  └─────────────────────────────────┘       │
└─────────────────────────────────────────────┘
```

### Dimensions

- Board Size: ~80mm x 80mm
- Package: FGG676 (31mm x 31mm)
- Mounting: 4x corner holes

---

## Testing & Debugging

### LED Test Design

Simple blink test to verify toolchain:

```verilog
module blink_test (
    input  wire clk,   // 50 MHz on U22
    output wire led    // R23 = D6
);
    reg [24:0] counter = 25'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    assign led = counter[24];  // ~3 Hz blink
endmodule
```

### JTAG Test

```bash
# Load firmware
sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex

# Test connection
sudo fpga/tools/detectchain
# Expected: 1 device: 0x13631093 (XC7A100T)
```

---

## Documentation Links

- [Xilinx Artix-7 Datasheet](https://www.xilinx.com/support/documentation/data_sheets/ds181_Artix_7_Data_Sheet.pdf)
- [7-Series FPGA User Guide](https://www.xilinx.com/support/documentation/user_guides/ug470_7Series_Config.pdf)
- [Project X-Ray Database](https://github.com/SymbiFlow/prjxray)

---

## Troubleshooting

### Board Not Detected

1. Check USB connection (Platform Cable)
2. Verify firmware loaded: `lsusb | grep 03fd`
3. Try replugging JTAG cable

### LED Not Lighting

1. Verify bitstream programmed
2. Check pin assignment (R23 for D6)
3. Confirm active-low logic (led = 0 for ON)

### Configuration Fails

1. Verify IDCODE: 0x13631093
2. Check bitstream integrity (sync word: 0xAA995566)
3. Retry programming

---

## φ² + 1/φ² = 3 = TRINITY
