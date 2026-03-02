// =========================================================================
// Testbench for trinity_top — LED blink verification
// Simulates 50 MHz clock, checks that LED toggles correctly
// Run: iverilog -o tb_trinity tb_trinity.v trinity_qmtech.v && vvp tb_trinity
// View: gtkwave tb_trinity.vcd
// =========================================================================

`timescale 1ns / 1ps

module tb_trinity;

    reg clk;
    wire led;

    // Instantiate DUT
    trinity_top dut (
        .clk(clk),
        .led(led)
    );

    // 50 MHz clock = 20ns period
    initial clk = 0;
    always #10 clk = ~clk;

    // Monitor
    integer cycle_count;
    reg led_prev;
    integer toggle_count;
    integer first_toggle_cycle;

    initial begin
        $dumpfile("tb_trinity.vcd");
        $dumpvars(0, tb_trinity);

        cycle_count = 0;
        toggle_count = 0;
        led_prev = 1'bx;
        first_toggle_cycle = 0;

        $display("═══════════════════════════════════════════════");
        $display(" TRINITY TESTBENCH — LED Blink Verification");
        $display(" Clock: 50 MHz (20ns period)");
        $display(" Expected: LED toggles every 2^24 = 16,777,216 cycles");
        $display("           = ~336ms = ~1.49 Hz blink rate");
        $display("═══════════════════════════════════════════════");
        $display("");

        // Check initial state
        #1;
        $display("[t=0] counter=%d, led=%b (active-low: LED %s)",
                 dut.counter, led, led ? "OFF" : "ON");

        // Simulate enough cycles to see LED toggle
        // 2^24 = 16,777,216 cycles at 20ns = 335.5ms
        // We'll simulate 2^25 + a bit to see at least 2 toggles
        // But that's 33M+ cycles — too slow for full sim
        // Instead: simulate 100 cycles for basic check, then
        // force counter near toggle point to verify transition

        // Phase 1: Basic clock counting (100 cycles)
        $display("");
        $display("[Phase 1] Basic counter operation (100 cycles)...");
        repeat(100) @(posedge clk);
        $display("  After 100 clocks: counter=%d (expected 100) %s",
                 dut.counter, (dut.counter == 100) ? "OK" : "FAIL");

        // Phase 2: Force counter near first toggle point
        $display("");
        $display("[Phase 2] Fast-forward to toggle point...");
        force dut.counter = 26'h0FF_FFFE;  // 2 cycles before bit[24] flips
        @(posedge clk);
        release dut.counter;
        $display("  counter=0x%07h, led=%b (bit24=%b)", dut.counter, led, dut.counter[24]);

        @(posedge clk);  // counter becomes 0x0FF_FFFF
        $display("  counter=0x%07h, led=%b (bit24=%b)", dut.counter, led, dut.counter[24]);

        @(posedge clk);  // counter becomes 0x100_0000 — bit[24] goes HIGH
        $display("  counter=0x%07h, led=%b (bit24=%b) << LED TOGGLES HERE",
                 dut.counter, led, dut.counter[24]);

        @(posedge clk);  // counter becomes 0x100_0001
        $display("  counter=0x%07h, led=%b (bit24=%b)", dut.counter, led, dut.counter[24]);

        // Verify LED is inverted counter[24]
        if (led == ~dut.counter[24])
            $display("  LED = ~counter[24]: PASS");
        else
            $display("  LED = ~counter[24]: FAIL (led=%b, expected %b)", led, ~dut.counter[24]);

        // Phase 3: Check second toggle (bit[24] goes back LOW)
        $display("");
        $display("[Phase 3] Second toggle point...");
        force dut.counter = 26'h1FF_FFFE;
        @(posedge clk);
        release dut.counter;

        @(posedge clk);  // 0x1FF_FFFF
        $display("  counter=0x%07h, led=%b (bit24=%b)", dut.counter, led, dut.counter[24]);

        @(posedge clk);  // 0x200_0000 — bit[24] goes LOW again
        $display("  counter=0x%07h, led=%b (bit24=%b) << LED TOGGLES BACK",
                 dut.counter, led, dut.counter[24]);

        // Phase 4: Counter wrap-around
        $display("");
        $display("[Phase 4] Counter wrap-around (26-bit)...");
        force dut.counter = 26'h3FF_FFFE;
        @(posedge clk);
        release dut.counter;

        @(posedge clk);  // 0x3FF_FFFF (max)
        $display("  counter=0x%07h (max 26-bit)", dut.counter);

        @(posedge clk);  // should wrap to 0
        $display("  counter=0x%07h (wrapped to 0) %s",
                 dut.counter, (dut.counter == 0) ? "OK" : "FAIL");

        // Summary
        $display("");
        $display("═══════════════════════════════════════════════");
        $display(" SIMULATION COMPLETE");
        $display(" Counter: 26-bit, increments every clock edge");
        $display(" LED: active-low, toggles at ~1.49 Hz");
        $display(" VCD file: tb_trinity.vcd (open with GTKWave)");
        $display("═══════════════════════════════════════════════");

        #100;
        $finish;
    end

endmodule
