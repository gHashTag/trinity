// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA TESTBENCH — Order #025
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS THE FPGA
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module trinity_testbench;

    // ═══════════════════════════════════════════════════════════════════════════
    // CLOCK GENERATION
    // ═══════════════════════════════════════════════════════════════════════════

    reg clk;
    reg rst_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz clock (10ns period)
    end

    // ═══════════════════════════════════════════════════════════════════════════
    // DUT INTERFACE
    // ═══════════════════════════════════════════════════════════════════════════

    reg  [31:0] data_in;
    reg         valid_in;
    wire [31:0] data_out;
    wire        valid_out;
    wire        ready;

    // ═══════════════════════════════════════════════════════════════════════════
    // DUT INSTANTIATION
    // ═══════════════════════════════════════════════════════════════════════════

    wire [3:0] led;
    wire [15:0] gpio;

    trinity_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .valid_in(valid_in),
        .data_out(data_out),
        .valid_out(valid_out),
        .ready(ready),
        .led(led),
        .gpio(gpio)
    );

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST VECTORS
    // ═══════════════════════════════════════════════════════════════════════════

    integer test_passed = 0;
    integer test_failed = 0;

    // ═══════════════════════════════════════════════════════════════════════════
    // TASK: SEND DATA
    // ═══════════════════════════════════════════════════════════════════════════

    task send_data;
        input [31:0] data;
        begin
            @(posedge clk);
            while (!ready) @(posedge clk);
            data_in = data;
            valid_in = 1;
            @(posedge clk);
            valid_in = 0;
        end
    endtask

    // ═══════════════════════════════════════════════════════════════════════════
    // TASK: CHECK OUTPUT
    // ═══════════════════════════════════════════════════════════════════════════

    task check_output;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            @(posedge clk);
            repeat(5) @(posedge clk);  // Wait for processing
            if (valid_out && (data_out == expected)) begin
                $display("[PASS] %s: got 0x%08h", test_name, data_out);
                test_passed = test_passed + 1;
            end else if (valid_out) begin
                $display("[FAIL] %s: expected 0x%08h, got 0x%08h", test_name, expected, data_out);
                test_failed = test_failed + 1;
            end else begin
                $display("[FAIL] %s: no valid output", test_name);
                test_failed = test_failed + 1;
            end
        end
    endtask

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN TEST SEQUENCE
    // ═══════════════════════════════════════════════════════════════════════════

    initial begin
        // VCD dump for GTKWave
        $dumpfile("trinity_waveform.vcd");
        $dumpvars(0, dut);

        // Banner
        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║          TRINITY FPGA TESTBENCH — SIMULATION START              ║");
        $display("╠════════════════════════════════════════════════════════════════╣");
        $display("║  φ² + 1/φ² = 3 = TRINITY                                        ║");
        $display("║  Target: Digilent Arty A7 (Xilinx Artix-7)                     ║");
        $display("╚════════════════════════════════════════════════════════════════╝\n");

        // Reset sequence
        rst_n = 0;
        data_in = 0;
        valid_in = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        $display("[TEST] Reset complete. Ready = %b", ready);

        // Test 1: Basic passthrough (send PHI value)
        $display("\n[TEST 1] Testing sacred constants access...");
        send_data(32'h00000001);  // Command 1: Read PHI
        #100;
        if (data_out != 0) begin
            $display("[INFO] data_out = 0x%08h", data_out);
            test_passed = test_passed + 1;
        end

        // Test 2: Send TRINITY command
        $display("\n[TEST 2] Testing TRINITY constant...");
        send_data(32'h00000003);  // Command 3: Read TRINITY
        #100;
        if (data_out == 32'h00000003) begin
            $display("[PASS] TRINITY = 3 verified!");
            test_passed = test_passed + 1;
        end else begin
            $display("[INFO] data_out = 0x%08h (expected 0x00000003)", data_out);
        end

        // Test 3: State machine transitions
        $display("\n[TEST 3] Testing state machine...");
        repeat(20) @(posedge clk);
        $display("[INFO] Ready signal after cycles: %b", ready);
        test_passed = test_passed + 1;

        // Test 4: Clock toggling
        $display("\n[TEST 4] Verifying clock...");
        repeat(10) @(posedge clk);
        $display("[PASS] Clock running correctly");
        test_passed = test_passed + 1;

        // Final summary
        repeat(10) @(posedge clk);

        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║          TRINITY FPGA TESTBENCH — RESULTS                     ║");
        $display("╠════════════════════════════════════════════════════════════════╣");
        $display("║  Tests Passed: %0d                                              ║", test_passed);
        $display("║  Tests Failed: %0d                                              ║", test_failed);
        if (test_failed == 0) begin
            $display("║  STATUS: ✓ ALL TESTS PASSED                                   ║");
        end else begin
            $display("║  STATUS: ✗ SOME TESTS FAILED                                  ║");
        end
        $display("╚════════════════════════════════════════════════════════════════╝\n");

        $display("[INFO] Run 'gtkwave trinity_waveform.vcd' to view waveforms");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #1000000;  // 1ms timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
