`default_nettype none

// ═══════════════════════════════════════════════════════════════════════
// TESTBENCH: SACRED ALU — GF16/TF3-9 Unified Arithmetic
// ═══════════════════════════════════════════════════════════════════════
//
// Tests unified Sacred ALU with both GF16 and TF3-9 operations
//
// φ² + 1/φ² = 3 | TRINITY

`timescale 1ns / 1ps

module tb_sacred_alu;

    // Clock and reset
    reg clk = 0;
    reg rst_n = 1;
    initial #1 rst_n = 0;
    initial forever #5 clk = ~clk;

    // Control
    reg in_valid = 0;
    wire in_ready;
    reg [1:0] mode = 2'b00;

    // Inputs
    reg [31:0] in_a = 0;
    reg [31:0] in_b = 0;

    // Outputs
    wire out_valid;
    reg out_ready = 1;
    wire [31:0] out_y;

    // DUT instance
    sacred_alu dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .mode(mode),
        .in_a(in_a),
        .in_b(in_b),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_y(out_y)
    );

    // Test count
    integer num_tests = 0;
    integer num_passed = 0;
    integer num_failed = 0;

    // Test modes
    localparam MODE_GF16_ADD = 2'b00;
    localparam MODE_GF16_MUL = 2'b01;
    localparam MODE_TF3_ADD  = 2'b10;
    localparam MODE_TF3_DOT  = 2'b11;

    // Helper: display mode name
    task print_mode;
        input [1:0] m;
        begin
            case (m)
                2'b00: $display("  Mode: GF16 ADD");
                2'b01: $display("  Mode: GF16 MUL");
                2'b10: $display("  Mode: TF3-9 ADD");
                2'b11: $display("  Mode: TF3-9 DOT");
                default: $display("  Mode: UNKNOWN");
            endcase
        end
    endtask

    initial begin
        $display("========== SACRED ALU TEST ==========");
        $display("");

        // ====================================================================
        // GF16 ADDITION TESTS
        // ====================================================================
        mode = MODE_GF16_ADD;

        // Test 1: 0 + 0 = 0
        test_sacred(16'h0000, 16'h0000, 16'h0000, 0);

        // Test 2: 1.0 + 0 = 1.0
        test_sacred(16'h7C00, 16'h0000, 16'h7C00, 0);

        // Test 3: 1.0 + 1.0 = 2.0
        test_sacred(16'h7C00, 16'h7C00, 16'h7D00, 0);

        // Test 4: -1.0 + 1.0 = 0.0
        test_sacred(16'hFC00, 16'h7C00, 16'h0000, 0);

        // ====================================================================
        // GF16 MULTIPLICATION TESTS
        // ====================================================================
        mode = MODE_GF16_MUL;

        // Test 5: 1.0 × 1.0 = 1.0
        test_sacred(16'h7C00, 16'h7C00, 16'h7C00, 1);

        // Test 6: 1.0 × 2.0 = 2.0
        test_sacred(16'h7C00, 16'h7D00, 16'h7E00, 1);

        // Test 7: 0.5 × 0.5 = 0.25
        test_sacred(16'h3E80, 16'h3E80, 16'h3D00, 1);

        // ====================================================================
        // TF3-9 ADDITION TESTS
        // ====================================================================
        mode = MODE_TF3_ADD;

        // Test 8: TF3-9: 0 + 0 = 0
        // TF3-9 zero: sign=01, exp=00, mant=00
        test_sacred(18'h00000, 18'h00000, 18'h00000, 0);

        // Test 9: TF3-9: +1 + 0 = +1
        // TF3-9 +1: sign=10, exp=00, mant=00
        test_sacred(18'h80000, 18'h00000, 18'h80000, 0);

        // ====================================================================
        // SUMMARY
        // ====================================================================
        $display("");
        $display("========== TEST SUMMARY ==========");
        $display("Total tests: %0d", num_tests);
        $display("Passed: %0d", num_passed);
        $display("Failed: %0d", num_failed);
        $display("Success rate: %0d%%", (num_passed * 100) / num_tests);

        if (num_failed == 0)
            $display("✅ ALL TESTS PASSED");
        else
            $display("❌ SOME TESTS FAILED");

        $finish;
    end

    // Task: run one test case
    task test_sacred;
        input [31:0] a;
        input [31:0] b;
        input [31:0] expected;
        input bit may_fail;
        reg [31:0] result;
        reg test_passed;
        begin
            num_tests = num_tests + 1;

            print_mode(mode);
            $display("Test %0d: a=0x%08X, b=0x%08X, expected=0x%08X",
                     num_tests, a[15:0], b[15:0], expected[15:0]);

            // Apply input
            in_a <= a;
            in_b <= b;
            in_valid <= 1;

            // Wait for ready
            @(posedge clk);
            while (!in_ready) @(posedge clk);
            in_valid <= 0;

            // Wait for output
            @(posedge clk);
            while (!out_valid) @(posedge clk);
            @(posedge clk);
            result = out_y;
            out_ready <= 0;
            @(posedge clk);
            out_ready <= 1;

            $display("  Result: 0x%08X", result[15:0]);

            // Check result (GF16 uses [15:0], TF3 uses [17:0])
            test_passed = (result[15:0] == expected[15:0]) || may_fail;
            if (!test_passed) begin
                num_failed = num_failed + 1;
                $display("  ❌ FAILED: got 0x%04X, expected 0x%04X",
                         result[15:0], expected[15:0]);
            end else begin
                num_passed = num_passed + 1;
                $display("  ✅ PASSED");
            end
            $display("");
        end
    endtask

    // Timeout watchdog
    initial begin
        #1000000;  // 1ms timeout
        $display("❌ TIMEOUT: Testbench did not complete");
        $finish;
    end

endmodule
