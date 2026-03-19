# Connecting ESP32 to FPGA Artix-7

## What Works Best?

| Interface | Complexity | Speed | Best For | Rating |
|-----------|-----------|--------|-----------|--------|
| **UART** | ⭐ Simple | ~1 Mbps | Commands, logs, debugging | ✅ **BEST TO START** |
| **SPI** | ⭐⭐ Medium | ~50 Mbps | Data, pixels | ⚡ Fast |
| **I2C** | ⭐ Simple | ~400 kHz | Sensors, settings | 🔧 For peripherals |
| **GPIO** | ⭐ Simplest | - | Buttons, LED | 💡 Control |

**RECOMMENDATION**: Start with **UART** — the simplest and most reliable option.

---

## Option 1: UART (Recommended)

### Connection Diagram

```
┌─────────────────────┐              ┌─────────────────────┐
│                     │              │                     │
│   ESP32 DIYTZT      │              │   FPGA Artix-7      │
│                     │              │   QMTECH XC7A100T   │
│                     │              │                     │
│  GPIO4 (TX) ────────┼──────────────┼──> L20 (UART_RX)   │
│                     │              │                     │
│  GPIO5 (RX) <───────┼──────────────┼── K20 (UART_TX)    │
│                     │              │                     │
│  GND ───────────────┼──────────────┼── GND (IMPORTANT!)  │
│                     │              │                     │
│  3.3V ──────────────┼──(optional)──┼── 3.3V (if needed) │
│                     │              │                     │
└─────────────────────┘              └─────────────────────┘
```

### ESP32 DIYTZT Pins

| ESP32 Pin | Name | Connect To | Note |
|-----------|------|-------------|-------|
| GPIO4 | TX | FPGA Pin L20 | ESP32 transmits |
| GPIO5 | RX | FPGA Pin K20 | ESP32 receives |
| GND | GND | FPGA GND | **REQUIRED!** |
| 3V3 | 3.3V | - | Don't connect (has its own) |
| 5V | 5V | - | Don't connect |

### FPGA Pins (FGG676)

| FPGA Pin | Bank | Name | Connect To |
|----------|------|------|-------------|
| L20 | 35 | IO_L1N_N0_A14_35 | ESP32 TX |
| K20 | 35 | IO_L1P_P0_A13_35 | ESP32 RX |
| GND | - | GND | ESP32 GND |

### Wires

Use:
- **DuPont wires** (Female-Female) — simplest option
- Or **jumper wires** with soldering iron

---

## Option 2: SPI (For High Speeds)

### Connection Diagram

```
ESP32                    FPGA
────────────────────────────────────────
GPIO14 (SCLK) ─────────> J21 (SPI_SCK)
GPIO12 (MISO) <───────── H21 (SPI_MISO)
GPIO13 (MOSI) ─────────> G22 (SPI_MOSI)
GPIO15 (CS) ───────────> F22 (SPI_CS)
GND ───────────────────> GND
```

**When to use**: When you need to transfer lots of data (e.g., pixels for LCD).

---

## Option 3: I2C (For Sensors)

### Connection Diagram

```
ESP32                    FPGA
────────────────────────────────────────
GPIO21 (SDA) ────────>── I2C_SDA (with 4.7k resistor)
GPIO22 (SCL) ────────>── I2C_SCL (with 4.7k resistor)
GND ───────────────────> GND
```

**Note**: Pull-up resistors 4.7kΩ required on SDA and SCL.

---

## Physical Connection (Step by Step)

### Method 1: DuPont Wires (Simplest)

1. Take 3 DuPont wires (Female-Female)
2. Connect:
   - **Black**: GND → GND
   - **White**: GPIO4 → Pin L20
   - **Blue**: GPIO5 → Pin K20
3. Check connections (with multimeter or visually)

### Method 2: PLS-EXT Board (Professional)

QMTech provides an expansion board with connectors:

```
PLS-EXT Connector:
┌────────────────────────────┐
│  GND  VCC  IO1  IO2  IO3   │
│   ↑    ↑    ↑    ↑    ↑    │
└────────────────────────────┘
```

Connect ESP32 to these pins.

---

## Testing Connections

### 1. Test GND (Required!)

```bash
# With multimeter: check continuity of GND ESP32 and GND FPGA
# Should be ~0 ohms
```

### 2. Check Voltage Levels

- ESP32: **3.3V logic** ✓
- FPGA: **3.3V logic** (LVCMOS33) ✓
- **Directly compatible!** (no converters needed)

### 3. Inspect Pins

| Check | How |
|-------|-----|
| Short circuit | Multimeter: VCC-GND should not beep |
| Correct pin | FPGA schematic + board markings |
| Bad contact | Wiggle the wire |

---

## Synthesis and Flashing FPGA

### 1. Synthesize Design

```bash
cd /Users/playra/trinity-w1/fpga/openxc7-synth

# Create simplified XDC (only for uart_bridge)
cat > uart_bridge.xdc << 'EOF'
# Clock
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# UART
set_property LOC L20 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

set_property LOC K20 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# LED
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
EOF

# Synthesize with openXC7
docker run --rm --platform linux/amd64 \
    -v "$(pwd):/work" -w /work \
    regymm/openxc7 \
    yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top uart_bridge; \
              write_json uart_bridge.json" \
    uart_bridge.v

# nextpnr + fasm2frames + xc7frames2bit
./synth.sh uart_bridge.v uart_bridge
```

### 2. Flash FPGA

```bash
# Load cable firmware
sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex

# Reconnect cable (wait 2 seconds)

# Flash bitstream
sudo fpga/tools/jtag_program uart_bridge.bit
```

---

## ESP32 Code (Arduino)

```cpp
// esp32_uart_fpga.ino
// Connection:
//   ESP32 GPIO4 (TX) -> FPGA L20 (RX)
//   ESP32 GPIO5 (RX) <- FPGA K20 (TX)
//   ESP32 GND       -> FPGA GND

#define RX_PIN 5
#define TX_PIN 4
#define BAUD_RATE 115200

// FPGA commands
#define CMD_PING      0x03
#define CMD_LED_ON    0x10
#define CMD_LED_OFF   0x11
#define CMD_LED_BLINK 0x12

// FPGA responses
#define RESP_PONG     0x83
#define RESP_OK       0xFF
#define RESP_ACK      0xAA

HardwareSerial SerialFPGA(1); // Use UART1

void setup() {
    Serial.begin(115200);
    SerialFPGA.begin(BAUD_RATE, SERIAL_8N1, RX_PIN, TX_PIN);

    Serial.println("=== ESP32 <-> FPGA UART Bridge ===");
    Serial.println("Commands: p=ping, o=on, f=off, b=blink");
}

void loop() {
    // Check commands from Serial Monitor
    if (Serial.available()) {
        char cmd = Serial.read();

        switch (cmd) {
            case 'p': // PING
                Serial.print("Sending PING... ");
                SerialFPGA.write(CMD_PING);
                break;

            case 'o': // LED ON
                Serial.print("Turning LED ON... ");
                SerialFPGA.write(CMD_LED_ON);
                break;

            case 'f': // LED OFF
                Serial.print("Turning LED OFF... ");
                SerialFPGA.write(CMD_LED_OFF);
                break;

            case 'b': // LED BLINK
                Serial.print("Blinking LED... ");
                SerialFPGA.write(CMD_LED_BLINK);
                break;

            default:
                Serial.println("Unknown command");
                break;
        }

        // Wait for FPGA response
        delay(100);
        if (SerialFPGA.available()) {
            uint8_t resp = SerialFPGA.read();
            Serial.print("Response: 0x");
            Serial.println(resp, HEX);
        } else {
            Serial.println("No response");
        }
    }

    // Relay data from FPGA to Serial Monitor
    if (SerialFPGA.available()) {
        uint8_t data = SerialFPGA.read();
        Serial.print("FPGA: 0x");
        Serial.println(data, HEX);
    }
}
```

### Upload to ESP32

1. Open Arduino IDE
2. Select board: **ESP32 Dev Module**
3. Select port: `/dev/cu.usbserial-*` (or COMx on Windows)
4. Upload sketch
5. Open Serial Monitor (115200 baud)
6. Send commands: `p`, `o`, `f`, `b`

---

## Testing

### Test 1: Check Communication

```bash
# In Arduino IDE Serial Monitor send:
p
# Should return: Response: 0x83
```

### Test 2: LED Control

```bash
o  # LED turns on
f  # LED turns off
b  # LED starts blinking
```

### Test 3: Oscilloscope

Check TX/RX signals with oscilloscope:
- Speed: 115200 baud
- Bits: 8N1 (8 data bits, No parity, 1 stop bit)
- Levels: 0V = logic 0, 3.3V = logic 1

---

## FPGA Pinout (Complete)

### Bank 35 (used for UART)

```
Pin  | Name          | ESP32 Connection
-----|---------------|------------------
L20  | IO_L1N_N0_A14 | UART_RX (GPIO4 TX)
K20  | IO_L1P_P0_A13 | UART_TX (GPIO5 RX)
M22  | IO_L2N_N1_A16 | Debug[0] (opt.)
N21  | IO_L2P_P1_A17 | Debug[1] (opt.)
N20  | IO_L3N_N2_A20 | Debug[2] (opt.)
P22  | IO_L3P_P2_A21 | Debug[3] (opt.)
```

### Pin Locations on FPGA

```
        ┌───────────────────────┐
        │                       │
        │   [FGG676 BGA]        │
        │                       │
        │  K20 L20  <- UART     │
        │   │   │               │
        └───┴───┴───────────────┘
```

---

## Troubleshooting

| Problem | Cause | Solution |
|----------|--------|----------|
| No FPGA response | GND not connected | Connect GND! |
| No FPGA response | Wrong pins | Check XDC file |
| ESP32 reboots | Power | Don't use 5V from FPGA |
| Garbage in Serial Monitor | Speed mismatch | Check BAUD_RATE |
| LED not working | Synthesis errors | Check synthesis logs |

---

## Next Steps

1. **VSA computations**: FPGA computes VSA, ESP32 displays on LCD
2. **WiFi bridge**: ESP32 forwards data via WiFi to computer
3. **LVGL interface**: Nice UI on ESP32 for FPGA control

φ² + 1/φ² = 3 = TRINITY
