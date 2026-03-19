# Professional FPGA Development — Guide 2026

## Table of Contents
1. Tools and comparison
2. Best Practices
3. ESP32-FPGA integration
4. How to level up the project
5. Learning resources

---

## 1. Tools and comparison

### Full development stack

```
┌─────────────────────────────────────────────────────────────┐
│                    FPGA Development Stack 2026              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Edit    │  │ Synthesis│  │  Place   │  │  Route   │   │
│  │          │  │          │  │          │  │          │   │
│  │ VS Code  │→ │  Yosys   │→ │ nextpnr  │→ │ nextpnr  │   │
│  │ Vim      │  │  Vivado  │  │  Vivado  │  │  Vivado  │   │
│  │ Sublime  │  │          │  │          │  │          │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│                                         │                   │
│                                         ↓                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  | Simulate│  | Verify  │  | Debug   │  | Program │   │
│  │          │  │          │  │          │  │          │   │
│  │Verilator│  │  Cocotb  │  │  ILA    │  │ OpenOCD  │   │
│  │ ModelSim │  │   UVM    │  │ ChipScope│  │  Vivado  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Toolchain comparison

| Tool | Status | Pros | Cons | When to use |
|-------|--------|------|-------|-------------|
| **Vivado** | 🔵 Proprietary | Best QoR, full stack | 50GB+, paid | Production |
| **Yosys** | 🟢 Open Source | Fast, cross-platform | -10% density | Open source projects |
| **nextpnr-xilinx** | 🟡 Experimental | Modern PnR | Xilinx 7-series alpha | Fun projects |
| **Verilator** | 🟢 Open Source | 100x faster than ModelSim | Syntax only | Verification |

### Recommendation for your project

```
┌─────────────────────────────────────────────────────────────┐
│                   Your situation                        │
├─────────────────────────────────────────────────────────────┤
│ ✓ Have: QMTECH XC7A100T                                    │
│ ✓ Have: openXC7 Docker (WORKING!)                          │
│ ✓ Have: FORGE (Zig) - experimental                    │
│ ✓ Have: JTAG cable                                        │
│                                                             │
│ RECOMMENDATION:                                              │
│ 1. Use openXC7 for production                      │
│ 2. Use Verilator for simulation                     │
│ 3. FORGE only for experiments                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Best Practices

### Coding standards

```systemverilog
// ===== CORRECT =====
module uart_tx #(
    parameter int CLK_FREQ = 50_000_000,
    parameter int BAUD_RATE = 115200
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [7:0]  tx_data,
    input  logic tx_start,
    output logic tx,
    output logic tx_busy
);

    // States
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t state, next_state;

    // Synchronous reset (preferred)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Combinatorial logic separately
    always_comb begin
        next_state = state;  // Default
        case (state)
            IDLE: begin
                if (tx_start) next_state = START;
            end
            // ...
        endcase
    end

endmodule
```

### CDC (Clock Domain Crossing)

```systemverilog
// ===== 2-flop synchronizer =====
module sync_2flop (
    input  logic clk_dst,
    input  logic async_sig,
    output logic sync_sig
);
    logic [1:0] sync_reg;

    always_ff @(posedge clk_dst) begin
        sync_reg <= {sync_reg[0], async_sig};
    end

    assign sync_sig = sync_reg[1];
endmodule
```

### Reset strategy

```systemverilog
// ===== Reset bridge (async -> sync) =====
module reset_bridge (
    input  logic clk,
    input  logic rst_n_async,
    output logic rst_n_sync
);
    logic [2:0] sync_reg;

    always_ff @(posedge clk or negedge rst_n_async) begin
        if (!rst_n_async) begin
            sync_reg <= 3'b000;
        end else begin
            sync_reg <= {sync_reg[1:0], 1'b1};
        end
    end

    assign rst_n_sync = sync_reg[2];
endmodule
```

---

## 3. ESP32-FPGA integration

### Recommended protocols

| Protocol | Speed | Complexity | Application |
|----------|--------|-------------|--------------|
| **UART** | 115200 - 921600 baud | ⭐ | Commands, debug |
| **SPI** | Up to 80 MHz | ⭐⭐ | Data, pixels |
| **I2C** | 400 kHz | ⭐ | Sensors |
| **Ethernet** | 100 Mbps | ⭐⭐⭐⭐ | Network |

### UART connection (recommended)

```
ESP32 DIYTZT              FPGA Artix-7
────────────────────────────────────────
GPIO4 (TX) ──────────────> L20 (RX)
GPIO5 (RX) <────────────── K20 (TX)
GND ─────────────────────> GND
```

### ESP32 code (Arduino)

```cpp
// esp32_fpga_uart.ino
#define RX_PIN 5
#define TX_PIN 4
#define BAUD 115200

HardwareSerial SerialFPGA(1);

void setup() {
    Serial.begin(115200);
    SerialFPGA.begin(BAUD, SERIAL_8N1, RX_PIN, TX_PIN);
    Serial.println("ESP32-FPGA Bridge Ready");
}

void loop() {
    // Relay Serial Monitor to FPGA
    if (Serial.available()) {
        SerialFPGA.write(Serial.read());
    }
    if (SerialFPGA.available()) {
        Serial.write(SerialFPGA.read());
    }
}
```

---

## 4. How to level up the project

### Level 1: Basic (current)

```
✅ Done:
- openXC7 toolchain configured
- Basic Verilog modules
- JTAG programming
- ESP32 UART bridge
```

### Level 2: Intermediate (next steps)

```
🔄 TODO:
- [ ] Add Verilator for simulation
- [ ] Create testbench for all modules
- [ ] Implement CDC checking
- [ ] Add assertions to code
- [ ] Setup CI/CD for tests
```

### Level 3: Advanced

```
🎯 TODO:
- [ ] Formal verification (SymbiYosys)
- [ ] UVM testbench
- [ ] Integrated Logic Analyzer
- [ ] Performance profiling
- [ ] Documentation generation
```

### Priorities

| Priority | Task | Time | Impact |
|----------|-------|-------|--------|
| 🔥 High | Verilator simulation | 2 days | High |
| 🔥 High | Testbench for UART | 1 day | High |
| 🔥 High | ESP32 code + LVGL | 3 days | High |
| ⚡ Medium | CDC checking | 2 days | Medium |
| ⚡ Medium | Assertions | 1 day | Medium |
| 💡 Low | UVM | 1 week | Low |

---

## 5. Learning resources

### Books

| Book | Author | Level |
|------|--------|-------|
| "FPGA Prototyping by Verilog Examples" | Pong P. Chu | Beginner |
| "Advanced FPGA Design" | Steve Kilts | Intermediate |
| "Computer Architecture: A Quantitative Approach" | Hennessy & Patterson | Advanced |

### Online courses

- **Nandland**: https://www.nandland.com/ (best for beginners)
- **FPGA4Fun**: https://www.fpga4fun.com/
- **ZipCPU**: https://zipcpu.com/ (advanced)

### GitHub projects to study

- **LiteX**: SoC builder in Python
- **VexRiscv**: 32-bit RISC-V in Scala/Verilog
- **picorv32**: Small RISC-V core
- **serdes**: High-speed serial examples

---

## 6. AliExpress analysis

### Link: https://th.aliexpress.com/item/1005009035385463.html

Probably an **ESP32-S3 with LCD display** or **FPGA expansion board**.

#### Typical board specs:

| Component | ESP32 Board | FPGA Board |
|-----------|-------------|------------|
| Microcontroller | ESP32-WROVER | - |
| FPGA | - | XC7A35T/100T |
| RAM | 8MB PSRAM | DDR3 |
| Flash | 16MB | SPI Flash |
| LCD | 2.4" ST7789 | - |
| Touch | Resistive | - |
| WiFi | 802.11 b/g/n | - |
| Bluetooth | BLE 4.2/5.0 | - |

#### What to choose for your project:

```
┌─────────────────────────────────────────────────────────────┐
│ YOUR CHOICE                                                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ 1. ESP32 + LCD (DIYTZT)                                     │
│    ✓ Already have                                              │
│    ✓ Great for UI                                     │
│    ✓ WiFi/Bluetooth for communication                         │
│                                                             │
│ 2. FPGA expansion (if that's what it is)                       │
│    ⚠️ Check compatibility with XC7A100T                    │
│    ⚠️ May duplicate current board                         │
│                                                             │
│ 3. Combo board (ESP32 + FPGA on one)                     │
│    ✅ Ideal for integration                              │
│    ✅ Fewer wires                                          │
│    ⚠️ Fewer I/O pins                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Quick Start Checklist

```bash
# 1. Simulation with Verilator
brew install verilator
cd fpga/openxc7-synth
verilator --Wall uart_bridge.v

# 2. Synthesis with openXC7
./synth.sh uart_bridge.v uart_bridge

# 3. Programming
sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex
# reconnect cable
sudo fpga/tools/jtag_program uart_bridge.bit

# 4. ESP32 code
# Open Arduino IDE, select "ESP32 Dev Module"
# Upload esp32_fpga_uart.ino
# Send commands from Serial Monitor
```

---

## Summary

| Aspect | Recommendation |
|--------|---------------|
| Toolchain | openXC7 for production |
| Simulation | Verilator |
| Verification | Cocotb + assertions |
| ESP32 connection | UART 115200 |
| LCD | LVGL on ESP32 |
| Next step | Add Verilator to project |

φ² + 1/φ² = 3 = TRINITY
