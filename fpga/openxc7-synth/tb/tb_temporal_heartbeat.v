// Testbench for temporal_heartbeat.v
// Tests: LED blinking at approximately 3 Hz

`timescale 1ns/1ps

module tb_temporal_heartbeat;
    // Signals
    reg clk;
    wire led;

    // DUT instantiation
    temporal_heartbeat_top dut(
        .clk(clk),
        .led(led)
    );

    // Clock generation: 50 MHz = 20ns period
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Test variables
    int toggle_count = 0;
    reg prev_led;
    time last_toggle_time;
    time period_ns;
    real frequency_hz;

    // Main test sequence
    initial begin
        $display("╔════════════════════════════════════════════════════════╗");
        $display("║     Temporal Heartbeat Testbench                       ║");
        $display("║     Expected: ~3 Hz blink (167ms ON, 167ms OFF)       ║");
        $display("╚════════════════════════════════════════════════════════╝");
        $display("");

        // Initialize
        prev_led = led;
        last_toggle_time = 0;

        // Wait for initial stabilization
        repeat(100) @(posedge clk);
        $display("[%0t] Initial state: LED=%b", $time, led);

        // Test 1: Count toggles over 1 second
        $display("\n[Test 1] Counting LED toggles over 1 second...");
        fork
            begin
                // 1 second timeout
                repeat(50000000) @(posedge clk);
            end
            begin
                // Monitor LED transitions
                forever begin
                    @(posedge clk);
                    if (led !== prev_led) begin
                        toggle_count++;
                        if (last_toggle_time > 0) begin
                            period_ns = $time - last_toggle_time;
                            frequency_hz = 1_000_000_000.0 / period_ns;
                            $display("  Toggle #%0d @ %0t (period=%0t ns, freq=%.2f Hz)",
                                     toggle_count, $time, period_ns, frequency_hz);
                        end
                        last_toggle_time = $time;
                        prev_led = led;
                    end
                end
            end
        join_any

        $display("\n[Test 1 Result] Total toggles in 1s: %0d", toggle_count);

        // Expected: 6 toggles (3 ON + 3 OFF) for 3 Hz
        // Allow tolerance: 4-8 toggles
        if (toggle_count >= 4 && toggle_count <= 8) begin
            $display("  ✓ PASS: LED blinking at correct frequency");
        end else begin
            $display("  ✗ FAIL: LED frequency incorrect (expected 4-8, got %0d)", toggle_count);
        end

        // Test 2: Verify LED actually toggles (not stuck)
        $display("\n[Test 2] Verifying LED toggles...");
        if (toggle_count > 0) begin
            $display("  ✓ PASS: LED is toggling");
        end else begin
            $display("  ✗ FAIL: LED is stuck at %b", led);
        end

        // Test 3: Check for active-low behavior (QMTECH LEDs)
        $display("\n[Test 3] Checking active-low behavior...");
        // Note: Active-low means LED=0 is ON, LED=1 is OFF
        $display("  Note: QMTECH LEDs are active-low (0=ON, 1=OFF)");
        $display("  Current state: LED=%b", led);

        $display("\n═════════════════════════════════════════════════════════");
        $display("Testbench completed at %0t", $time);
        $display("═════════════════════════════════════════════════════════");

        $finish;
    end

    // Timeout watchdog (prevent infinite simulation)
    initial begin
        #2000000000;  // 2 second timeout
        $display("\n[ERROR] Testbench timeout!");
        $finish;
    end

    // Dump VCD for waveform viewing
    initial begin
        $dumpfile("tb_temporal_heartbeat.vcd");
        $dumpvars(0, tb_temporal_heartbeat);
    end

endmodule
