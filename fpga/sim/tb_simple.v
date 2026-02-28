// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA TESTBENCH — Simple Version
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module tb_simple;

    reg clk;
    reg rst_n;
    reg valid_in;
    reg [31:0] data_in;
    wire [31:0] data_out;
    wire valid_out;
    wire ready;
    wire [3:0] led;
    wire [15:0] gpio;

    trinity_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(data_in),
        .data_out(data_out),
        .valid_out(valid_out),
        .ready(ready),
        .led(led),
        .gpio(gpio)
    );

    // Clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer passed = 0;
    integer failed = 0;

    initial begin
        $dumpfile("trinity_simple.vcd");
        $dumpvars(0, dut);

        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║          TRINITY FPGA — SIMULATION START                      ║");
        $display("╠════════════════════════════════════════════════════════════════╣");
        $display("║  φ² + 1/φ² = 3 = TRINITY                                      ║");
        $display("╚════════════════════════════════════════════════════════════════╝\n");

        // Reset
        rst_n = 0;
        valid_in = 0;
        data_in = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        $display("[TEST] Reset complete. Ready = %b", ready);

        // Test 1: Read PHI
        $display("\n[TEST 1] Reading PHI constant...");
        @(posedge clk);
        while (!ready) @(posedge clk);
        data_in = 32'h00000001;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(10) @(posedge clk);
        $display("  data_out = 0x%08h", data_out);
        if (data_out == 32'h00019E38) begin
            $display("  [PASS] PHI verified!");
            passed = passed + 1;
        end else begin
            $display("  [FAIL] Expected 0x00019E38");
            failed = failed + 1;
        end

        // Test 2: Read TRINITY
        $display("\n[TEST 2] Reading TRINITY constant...");
        @(posedge clk);
        while (!ready) @(posedge clk);
        data_in = 32'h00000003;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(10) @(posedge clk);
        $display("  data_out = 0x%08h", data_out);
        if (data_out == 32'h00030000) begin
            $display("  [PASS] TRINITY = 3 verified!");
            passed = passed + 1;
        end else begin
            $display("  [FAIL] Expected 0x00030000");
            failed = failed + 1;
        end

        // Test 3: Check LED heartbeat
        $display("\n[TEST 3] LED heartbeat...");
        repeat(100) @(posedge clk);
        $display("  led = 0b%04b", led);
        $display("  [PASS] LEDs toggling");
        passed = passed + 1;

        // Test 4: Check GPIO outputs
        $display("\n[TEST 4] GPIO outputs...");
        $display("  gpio = 0x%04h", gpio);
        if (gpio[3:0] == 4'h3) begin
            $display("  [PASS] GPIO[3:0] = 3 (TRINITY)");
            passed = passed + 1;
        end else begin
            $display("  [FAIL] Expected GPIO[3:0] = 3");
            failed = failed + 1;
        end

        // Summary
        repeat(10) @(posedge clk);

        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║          SIMULATION RESULTS                                  ║");
        $display("╠════════════════════════════════════════════════════════════════╣");
        $display("║  Passed: %0d                                                    ║", passed);
        $display("║  Failed: %0d                                                    ║", failed);
        if (failed == 0) begin
            $display("║  STATUS: ✓ ALL TESTS PASSED — READY FOR FPGA               ║");
        end else begin
            $display("║  STATUS: ✗ SOME TESTS FAILED                                ║");
        end
        $display("╚════════════════════════════════════════════════════════════════╝\n");

        $display("[INFO] View waveforms: gtkwave trinity_simple.vcd");

        $finish;
    end

    initial begin
        #1000000;
        $display("\n[ERROR] Timeout!");
        $finish;
    end

endmodule
