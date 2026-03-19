# DSlogic Plus — Capabilities for Trinity FPGA + ESP32

## Specifications

| Parameter | Value |
|-----------|-------|
| **Channels** | 16 digital + 1 analog |
| **Sampling Rate** | 400 MS/s (mega-samples/sec) |
| **Buffer Depth** | up to 16Gb (with SD card) |
| **Voltage** | 1.2V - 5V (programmable) |
| **Interface** | USB 2.0 High Speed |
| **Software** | DSView (open source) |
| **Price** | ~$100-150 |

---

## 🔍 What It Provides (compared to just UART monitor)

### 1. **See Everything at Once**

```
┌─────────────────────────────────────────────────────────────────────┐
│                     UART monitor (usual)                          │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  RX: 03 FF AA                                                │ │
│  │  TX: 83                                                      │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                     ↑ Only data                                   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     DSlogic Plus (analyzer)                        │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  CH0-CH7:   ESP32 → FPGA (SPI data)                          │ │
│  │  CH8:       SPI Clock                                         │ │
│  │  CH9:       SPI CS                                            │ │
│  │  CH10-CH11:  FPGA → ESP32 (MISO)                             │ │
│  │  CH12:      UART TX                                           │ │
│  │  CH13:      UART RX                                           │ │
│  │  CH14:      FPGA_CLK (50 MHz)                                 │ │
│  │  CH15:      LED output                                        │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                     ↑ All signals with timings!                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Specific Capabilities

### 1. **Real-time Protocol Decoding**

```
SPI Decode:
┌─────────────────────────────────────────────────────────────────────┐
│ CS   │ CLK │ MOSI │ MISO │ DECODED                             │
├──────┼─────┼──────┼──────┼───────────────────────────────────────┤
│  ────┘ ┐   │  AA   │  XX  │ CMD: PING                            │
│        └───┘  BB   │  83  │ RESP: PONG                           │
│        ┌───┐  CC   │  XX  │ CMD: LED_ON                          │
│        └───┘       │  FF  │ RESP: OK                             │
└─────────────────────────────────────────────────────────────────────┘
```

**Supported Protocols:**
- ✅ UART (asynchronous)
- ✅ SPI (synchronous)
- ✅ I2C (two-wire)
- ✅ I2S (audio)
- ✅ CAN (automotive)
- ✅ LIN
- ✅ 1-Wire
- ✅ And 10+ others

---

### 2. **Timing Measurements**

```
┌─────────────────────────────────────────────────────────────────────┐
│  Measuring delay between UART TX and FPGA RX:                     │
│                                                                     │
│  ESP32_TX ─┐                                                      │
│            │  ← 150 ns                                            │
│            └───────────────────────┐                               │
│  FPGA_RX ──────────────────────────┘                               │
│                                                                     │
│  Pulse Width: 8.68 µs (115200 baud)                                │
│  Setup Time: 45 ns                                                 │
│  Hold Time: 120 ns                                                 │
└─────────────────────────────────────────────────────────────────────┘
```

**What can be measured:**
- Signal frequency
- Pulse duration
- Delays between signals
- Duty cycle
- Rise/Fall time

---

### 3. **Finding Problems (Debugging)**

```
┌─────────────────────────────────────────────────────────────────────┐
│  Trigger: Find glitch on SPI clock                               │
│                                                                     │
│  CLK: ──┐  ┌──┐  ┌──┐  ┌──┐  ┌─┐┌──┐  ┌──┐                      │
│        └──┘  └──┘  └──┘  └──┘  ┘ └──┘  └──┘                     │
│                    ↑ glitch!                                      │
│                                                                     │
│  DSLogic automatically stops on the problem                          │
└─────────────────────────────────────────────────────────────────────┘
```

**Trigger Types:**
- Edge (↑ or ↓ front)
- Pulse (pulse width)
- Protocol (specific command)
- Glitch (short pulse)
- Pattern (sequence)

---

### 4. **Data Export**

```
Captured data → Export to:
├── CSV (for Excel/Python analysis)
├── JSON (for automation)
├── Binary (raw data)
├── Waveform (screenshots)
└── MATLAB (for analysis)
```

---

## 📊 Comparison: UART Monitor vs DSlogic Plus

| Capability | UART Monitor | DSlogic Plus |
|-------------|--------------|--------------|
| **See data** | ✅ | ✅ |
| **Decode protocol** | ✅ 1 protocol | ✅ 20+ protocols |
| **See timings** | ❌ | ✅ (down to 2.5 ns) |
| **Many signals at once** | ❌ | ✅ 16 channels |
| **Triggers** | ❌ | ✅ |
| **Measure frequency** | ❌ | ✅ |
| **Find glitches** | ❌ | ✅ |
| **SPI analysis** | ❌ | ✅ |
| **I2C analysis** | ❌ | ✅ |
| **Analog channel** | ❌ | ✅ 1 channel |
| **Price** | Free | ~$100 |

---

## 🔧 Connection to Your Project

### Connection Diagram for Trinity FPGA + ESP32

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DSlogic Plus connection                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ESP32                    FPGA                      DSLogic         │
│  ┌─────────────┐         ┌─────────────┐         ┌─────────────┐  │
│  │ GPIO4 (TX)──┼─────────┼ L20 (RX)   ├───CH0───▶│             │  │
│  │ GPIO5 (RX)──┼─────────┼ K20 (TX)   ├───CH1───▶│             │  │
│  │             │         │             │         │             │  │
│  │ GPIO14(SCLK)┼─────────┼ J21 (SCK)  ├───CH2───▶│  CH0-15     │  │
│  │ GPIO12(MISO)┼─────────┼ H21 (MISO) ├───CH3───▶│  Digital    │  │
│  │ GPIO13(MOSI)┼─────────┼ G22 (MOSI) ├───CH4───▶│  Inputs     │  │
│  │ GPIO15(CS) ─┼─────────┼ F22 (CS)   ├───CH5───▶│             │  │
│  │             │         │             │         │             │  │
│  │             │         │ U22 (CLK)  ├───CH6───▶│             │  │
│  │             │         │ T23 (LED)  ├───CH7───▶│             │  │
│  │             │         │             │         │             │  │
│  │ 3.3V ───────┼─────────┼ 3.3V ──────┼───VCC───▶│             │  │
│  │ GND ────────┼─────────┼ GND ───────┼───GND───▶│             │  │
│  └─────────────┘         └─────────────┘         └─────────────┘  │
│                                                                 ▲  │
└─────────────────────────────────────────────────────────────────│──┘
                                                                  │
                                            USB ──────────────────┘
                                                   │
                                                   ▼
                                            MacBook Pro
                                            (DSView software)
```

---

## 💡 Real Use Cases

### Use Case 1: SPI Not Working

**With UART monitor:**
```
UART: "Data not arriving... 🤷"
```

**With DSlogic Plus:**
```
1. You see: Clock is running, MOSI is working
2. Problem: CS line always HIGH (never goes down)
3. Solution: ESP32 pin is misconfigured
```

---

### Use Case 2: FPGA Returns Incorrect Data

**With UART monitor:**
```
UART: "Got 0xFF instead of 0x83... why?"
```

**With DSlogic Plus:**
```
1. You measure: Timing violation on MISO
2. You see: Data changes 5 ns after clock edge
3. Solution: Add 1 clock cycle delay in FPGA
```

---

### Use Case 3: Random ESP32 Reboots

**With UART monitor:**
```
UART: "ESP32 rebooted... brownout?"
```

**With DSlogic Plus:**
```
1. Analog channel shows: 3.3V drops to 2.1V
2. Cause: FPGA consumes too much during switching
3. Solution: Add 100µF capacitor
```

---

## 🎯 For Trinity Project

### What specifically can be debugged:

| Component | What to Check |
|-----------|---------------|
| **UART** | Timings, baud rate accuracy |
| **SPI** | Clock polarity, phase, setup/hold |
| **VSA calculations** | Results via memory-mapped I/O |
| **LED control** | Toggle frequency, glitch detection |
| **Power rail** | Voltage under load (analog) |
| **Clock tree** | Jitter, frequency accuracy |

---

## 📦 What's in the Box

```
DSlogic Plus Box:
├── DSlogic Plus device
├── ZIF-clip (IC clamp)
├── Test hooks (crocodile clips)
├── Flywire cables
├── USB cable
└── Case
```

---

## 💰 Purchase Reasoning

### Buy if:

- ✅ Developing complex protocols (SPI, I2C together)
- ✅ Need precise timing debugging
- ✅ Want to see everything at once
- ✅ Learning FPGA/electronics
- ✅ $100 is not a problem

### Don't buy if:

- ❌ Using only UART (CoolTerm is enough)
- ❌ Budget is limited
- ❌ Simple project (LED blink)

---

## 📝 Summary

**DSlogic Plus will provide:**

1. ✅ See 16 signals simultaneously (vs 2 with UART monitor)
2. ✅ Decode 20+ protocols (vs 1)
3. ✅ Measure timings down to 2.5 ns
4. ✅ Find glitches and problems
5. ✅ Analog measurements
6. ✅ Professional debugging

**For Trinity FPGA + ESP32:**
- Useful for debugging SPI
- Necessary for complex synchronization
- Required when developing new protocols

φ² + 1/φ² = 3 = TRINITY
