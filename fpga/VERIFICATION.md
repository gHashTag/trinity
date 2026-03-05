# FPGA Verification Guide

Industry-standard verification methods for Trinity FPGA development.

---

## Overview

LED blinking tests are **NOT sufficient** for real verification. This guide covers comprehensive methods.

### Verification Hierarchy

```
┌─────────────────────────────────────────────┐
│            Hardware (FPGA)                  │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐ │
│  │   ILA   │    │   UART  │    │   LED   │ │
│  │ Debug   │    │  Tests  │    │  Tests  │ │
│  └─────────┘    └─────────┘    └─────────┘ │
└─────────────────────────────────────────────┘
           ↑              ↑              ↑
┌─────────────────────────────────────────────┐
│           Simulation (Testbench)            │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐ │
│  │UVM Env  │    │ Formal  │    │Cov     │ │
│  └─────────┘    └─────────┘    └─────────┘ │
└─────────────────────────────────────────────┘
```

---

## Part 1: Simulation Testbenches

### Directory Structure

```
fpga/openxc7-synth/tb/
├── tb_temporal_heartbeat.v
├── tb_ternary_dot.v
├── tb_vsa_operations.v
└── Makefile
```

### Basic Testbench Template

```verilog
// tb_temporal_heartbeat.v
`timescale 1ns/1ps

module tb_temporal_heartbeat;
    reg clk = 0;
    reg led;

    // DUT instantiation
    temporal_heartbeat_top dut(.clk(clk), .led(led));

    // Clock generation: 50 MHz = 20ns period
    always #10 clk = ~clk;

    // Test sequence
    initial begin
        $display("=== Temporal Heartbeat Testbench ===");
        $display("Time: %0t", $time);

        // Test 1: Reset behavior
        repeat(100) @(posedge clk);
        $display("After reset: LED=%b", led);

        // Test 2: Count LED toggles over time
        // Expected: ~3 Hz blink (167ms ON, 167ms OFF)
        fork
            begin
                // Wait for 1 second (50 million cycles)
                repeat(50000000) @(posedge clk);
            end
            begin
                // Count LED transitions
                int toggle_count = 0;
                reg prev_led = led;
                forever begin
                    @(posedge clk);
                    if (led !== prev_led) begin
                        toggle_count++;
                        prev_led = led;
                        $display("Toggle @ %0t: LED=%b (count=%0d)",
                                 $time, led, toggle_count);
                    end
                end
            end
        join_any

        $display("Total toggles in 1s: %0d (expected ~6)", toggle_count);

        if (toggle_count >= 5 && toggle_count <= 7)
            $display("PASS: LED blinking at correct frequency");
        else
            $display("FAIL: LED frequency incorrect");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #1000000000;  // 1 second timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
endmodule
```

### Running Simulation

```bash
# Using Icarus Verilog
cd fpga/openxc7-synth/tb
iverilog -g2012 -o tb_sim tb_temporal_heartbeat.v ../temporal_heartbeat.v
vvp tb_sim

# Using Verilator
verilator --cc --exe tb_temporal_heartbeat.v ../temporal_heartbeat.v
make -C obj_dir -f Vtemporal_heartbeat.mk
./obj_dir/Vtemporal_heartbeat

# View waveforms (GTKWave)
gtkwave tb.vcd
```

### Makefile for Testbenches

```makefile
# fpga/openxc7-synth/tb/Makefile

VERILOG_FILES = $(wildcard ../*.v)
TESTBENCH_FILES = $(wildcard tb_*.v)
SIMULATOR = iverilog

.PHONY: all clean simulate

all: simulate

simulate:
    @for tb in $(TESTBENCH_FILES); do \
        echo "Running $$tb..."; \
        $(SIMULATOR) -g2012 -o $${tb%.v} $$tb $(VERILOG_FILES); \
        vvp $${tb%.v}; \
    done

clean:
    rm -f tb_*_sim *.vcd

%.vcd: %
    vvp $< -lxt2
```

---

## Part 2: UART-Based Hardware Testing

**Problem**: Vivado ILA (Integrated Logic Analyzer) is proprietary.

**Solution**: Use UART for real-time debugging on open-source toolchain.

### UART Transmitter Module

```verilog
// fpga/rtl/uart_tx.v
module uart_tx (
    input wire clk,
    input wire [7:0] data,
    input wire start,
    output reg uart_tx,
    output reg busy
);
    parameter CLK_FREQ = 50_000_000;
    parameter BAUD = 115200;

    localparam DIVISOR = CLK_FREQ / BAUD;
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [31:0] counter = 0;
    reg [3:0] bit_idx = 0;
    reg [7:0] shift_reg;
    reg [1:0] state;

    always @(posedge clk) begin
        counter <= counter + 1;
        if (counter >= DIVISOR - 1) begin
            counter <= 0;

            case (state)
                IDLE: begin
                    uart_tx <= 1;
                    if (start) begin
                        shift_reg <= data;
                        bit_idx <= 0;
                        state <= START;
                        busy <= 1;
                    end else begin
                        busy <= 0;
                    end
                end

                START: begin
                    uart_tx <= 0;
                    state <= DATA;
                end

                DATA: begin
                    uart_tx <= shift_reg[bit_idx];
                    bit_idx <= bit_idx + 1;
                    if (bit_idx == 7)
                        state <= STOP;
                end

                STOP: begin
                    uart_tx <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
```

### FPGA Test Reporter

```verilog
// fpga/rtl/fpga_test_reporter.v
module fpga_test_reporter (
    input wire clk,
    output wire uart_tx,
    output wire led
);
    // Send test results via UART
    // Format: "PASS:test_name\n" or "FAIL:test_name:reason\n"

    reg [7:0] test_string [0:31];
    reg [4:0] idx = 0;
    reg sending = 0;
    reg [7:0] char_to_send;

    uart_tx uart (
        .clk(clk),
        .data(char_to_send),
        .start(sending),
        .uart_tx(uart_tx),
        .busy()
    );

    // Test: Temporal Heartbeat
    reg [23:0] blink_counter;
    reg led_state;
    reg test_running;

    always @(posedge clk) begin
        if (blink_counter == 24'd0) begin
            led_state <= ~led_state;
        end
        blink_counter <= blink_counter + 1;
    end

    assign led = led_state;

    // Send test results
    always @(posedge clk) begin
        if (test_running && idx < 32) begin
            if (!uart.busy) begin
                char_to_send <= test_string[idx];
                sending <= 1;
                idx <= idx + 1;
            end else begin
                sending <= 0;
            end
        end
    end

endmodule
```

### Receiving UART Output

```bash
# Connect USB-UART adapter (GPIO pins on FPGA)
# RX: FPGA UART_TX → USB RX
# GND: FPGA GND → USB GND

# Screen (macOS/Linux)
screen /dev/tty.usbserial-*. 115200

# Or picocom
picocom -b 115200 /dev/tty.usbserial-*

# Expect output:
# PASS:temporal_heartbeat
# PASS:led_toggles
# FAIL:timing_violation
```

---

## Part 3: Formal Verification

### Using SymbiYosys (open-source)

```verilog
// temporal_heartbeat_sva.sv
`include "sva.sv"

module temporal_heartbeat_sva;
    wire clk;
    wire led;
    wire [24:0] counter;

    // Property: LED toggles periodically
    property led_toggles;
        @(posedge clk)
        (counter == 25'd0) |-> ##[40000000:45000000] (counter == 25'd0);
    endproperty

    assert_led_toggles: assert property(led_toggles)
        else $error("LED toggle period violation");

    // Property: Counter always increments
    property counter_increments;
        @(posedge clk)
        (counter < 25'h1ffffff) |=> (counter == $past(counter) + 1);
    endproperty

    assert_counter_increments: assert property(counter_increments)
        else $error("Counter increment violation");

endmodule
```

### Running Formal Verification

```bash
# Install SymbiYosys
brew install symbiyosys

# Create sby config
cat > temporal_heartbeat.sby << 'EOF'
[tasks]
formal

[options]
mode prove
depth 100

[engines]
sby

[script]
verilator -cc temporal_heartbeat.v temporal_heartbeat_sva.sv

[formal]
EOF

# Run
sby temporal_heartbeat.sby
```

---

## Part 4: Coverage-Driven Verification

### Code Coverage

```verilog
// Add coverage points
covergroup cg_led_transitions @(posedge clk);
    coverpoint led {
        bins zero = {0};
        bins one = {1};
    }
    coverpoint led_prev {
        bins zero = {0};
        bins one = {1};
    }
    transition: coverpoint led_prev -> led {
        bins rising = (0 => 1);
        bins falling = (1 => 0);
    }
endgroup

cg_led_transitions cg_led = new;
```

### Functional Coverage

```bash
# Use Verilator with coverage
verilator --cc --coverage ../temporal_heartbeat.v tb_temporal_heartbeat.v
make -C obj_dir -f Vtemporal_heartbeat.mk Vtemporal_heartbeat
./obj_dir/Vtemporal_heartbeat

# Generate coverage report
verilator_coverage annotate obj_dir/coverage.dat
```

---

## Part 5: UVM Environment (Advanced)

**Note**: Requires SystemVerilog toolchain. May not work fully with open-source tools.

### Directory Structure

```
fpga/uvm/
├── agent/
│   ├── driver.sv
│   ├── monitor.sv
│   └── scoreboard.sv
├── env/
│   └── base_test.sv
├── sequences/
│   └── test_sequence.sv
└── tests/
    └── basic_test.sv
```

### Basic UVM Test

```systemverilog
// fpga/uvm/tests/basic_test.sv
`include "uvm_macros.svh"
import uvm_pkg::*;

class basic_test extends uvm_test;
    `uvm_component_utils(basic_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", "Starting basic test", UVM_LOW)

        // Test logic here

        phase.drop_objection(this);
    endtask
endclass
```

---

## Part 6: Hardware-In-The-Loop Testing

### Test Procedure

1. **Generate bitstream** (openXC7 or FORGE)
2. **Program FPGA** via JTAG
3. **Apply stimuli** via UART/GPIO
4. **Capture responses** via UART/Logic Analyzer
5. **Verify against expected**

### Automated Test Script

```bash
#!/bin/bash
# fpga/openxc7-synth/test_hardware.sh

set -e

DESIGN=$1
PORT=/dev/tty.usbserial-*

echo "Programming FPGA..."
sudo ../tools/jtag_program ${DESIGN}.bit

echo "Waiting for boot..."
sleep 2

echo "Capturing UART output..."
timeout 5s cat $PORT > /tmp/test_output.txt || true

echo "Checking results..."
if grep -q "PASS" /tmp/test_output.txt; then
    echo "HARDWARE TEST PASSED"
    exit 0
else
    echo "HARDWARE TEST FAILED"
    cat /tmp/test_output.txt
    exit 1
fi
```

---

## Part 7: Debugging Workflow

### When Hardware Fails

```
1. Check XDC constraints
   ↓
2. Verify synthesis warnings
   ↓
3. Run simulation testbench
   ↓
4. Check FASM for correct routing
   ↓
5. Use UART to dump internal state
   ↓
6. Compare expected vs actual timing
   ↓
7. Fix and re-test
```

### Common Issues

| Symptom | Possible Cause | Debug Step |
|---------|---------------|------------|
| LED always ON | Active-low confusion | Check logic inversion |
| LED always OFF | Wrong pin in XDC | Verify package pin |
| Wrong frequency | Counter size issue | Check bit width |
| Random behavior | Timing violation | Add constraints |

---

## Quick Reference

| Method | Tool | Use Case |
|--------|------|----------|
| Simulation | Icarus Verilog | Pre-synthesis verification |
| Formal | SymbiYosys | Mathematical proof |
| Coverage | Verilator | Test completeness |
| UART Debug | Custom | Real-time monitoring |
| Hardware Test | Script | Final validation |

---

## φ² + 1/φ² = 3 = TRINITY
