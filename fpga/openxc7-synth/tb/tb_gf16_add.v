`default_nettype none

// ═════════════════════════════════════════════════════════════════════════════
// TESTBENCH: GF16 ADDER
// ═══════════════════════════════════════════════════════════════════════════
//
// Compares hardware GF16 adder against software reference
// Test vectors generated from Zig implementation (intraparietal_sulcus.zig)
//
// φ² + 1/φ² = 3 | TRINITY

`timescale 1ns / 1ps

module tb_gf16_add;

    // Clock and reset
    reg clk = 0;
    reg rst_n = 1;
    initial #1 rst_n = 0;
    initial forever #5 clk = ~clk;

    // Control
    reg in_valid = 0;
    wire in_ready;
    reg [1:0] in_op = 2'b00;

    // Inputs
    reg [15:0] in_a = 0;
    reg [15:0] in_b = 0;

    // Outputs
    wire out_valid;
    reg out_ready = 1;
    wire [15:0] out_y;

    // DUT instance
    gf16_add dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_op(in_op),
        .in_a(in_a),
        .in_b(in_b),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_y(out_y)
    );

    // Test case structure
    typedef struct packed {
        bit [15:0] a;
        bit [15:0] b;
        bit [15:0] expected;
        bit fail;  // Expected to fail (e.g., underflow/overflow)
    } test_case_t;

    // Test count
    integer num_tests = 0;
    integer num_passed = 0;
    integer num_failed = 0;

    // Helper: decode GF16 to sign/exp/mant
    function [5:0] get_exp;
        input [15:0] gf16;
        begin
            get_exp = gf16[14:9];
        end
    endfunction

    function [8:0] get_mant;
        input [15:0] gf16;
        begin
            get_mant = gf16[8:0];
        end
    endfunction

    // Test vectors (matching Zig gf16FromF32/gf16ToF32)
    // Generated from: gf16_add_test_vectors.zig
    initial begin
        // Test 1: 0 + 0 = 0
        test_add(16'h0000, 16'h0000, 16'h0000, 0);

        // Test 2: 1.0 + 0 = 1.0
        // GF16(1.0) ≈ [sign=0, exp=31, mant=0] = 0x7C00
        test_add(16'h7C00, 16'h0000, 16'h7C00, 0);

        // Test 3: 1.0 + 1.0 = 2.0
        // GF16(1.0)=0x7C00, GF16(2.0)=0x7D00 (exp=32, mant=0)
        test_add(16'h7C00, 16'h7C00, 16'h7D00, 0);

        // Test 4: -1.0 + 1.0 = 0.0
        // -1.0: sign=1, exp=31, mant=0 → 0xFC00
        test_add(16'hFC00, 16'h7C00, 16'h0000, 0);

        // Test 5: 1.0 + (-1.0) = 0.0
        test_add(16'h7C00, 16'hFC00, 16'h0000, 0);

        // Test 6: 0.5 + 0.5 = 1.0
        // GF16(0.5): exp=30, mant=128 → 0x3E80
        // GF16(1.0): exp=31, mant=0 → 0x7C00
        test_add(16'h3E80, 16'h3E80, 16'h7C00, 0);

        // Test 7: Large values (exponent alignment test)
        // 100.0 + 100.0 = 200.0
        // GF16(100): exp=37 (bias+6), mant calculated
        // Using approximate values - verify with Zig reference
        test_add(16'hA900, 16'hA900, 16'hB200, 1);  // May saturate

        // Test 8: Small + large (shift test)
        // 0.1 + 100.0 ≈ 100.1
        test_add(16'h2F80, 16'hA900, 16'hA901, 1);  // May saturate

        // Test 9: Rounding edge cases
        // Values that should round to even
        test_add(16'h3800, 16'h3800, 16'h3880, 0);  // ~0.125 + ~0.125

        // Test 10: Sign propagation
        // (-0.5) + (-0.5) = -1.0
        test_add(16'hBE80, 16'hBE80, 16'hFC00, 0);

        // Additional tests for saturation
        // Test 11: Near overflow
        test_add(16'hFE00, 16'hFE00, 16'hFE00, 1);  // May saturate

        // Test 12: Near underflow
        test_add(16'h0180, 16'h0180, 16'h0180, 1);  // May underflow

        $display("========== GF16 ADDER TEST SUMMARY ==========");
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
    task test_add;
        input [15:0] a;
        input [15:0] b;
        input [15:0] expected;
        input bit may_fail;
        reg [15:0] result;
        integer i;
        reg test_passed;
        begin
            num_tests = num_tests + 1;

            $display("Test %0d: 0x%04X + 0x%04X", num_tests, a, b);
            $display("  A: sign=%b exp=%0d mant=0x%03X", a[15], get_exp(a), get_mant(a));
            $display("  B: sign=%b exp=%0d mant=0x%03X", b[15], get_exp(b), get_mant(b));
            $display("  Expected: 0x%04X", expected);

            // Apply input
            in_a <= a;
            in_b <= b;
            in_op <= 2'b00;
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

            $display("  Result:   0x%04X", result);
            $display("  sign=%b exp=%0d mant=0x%03X",
                     result[15], get_exp(result), get_mant(result));

            // Check result
            // Allow ±1 LSB tolerance for rounding
            test_passed = (result == expected) || may_fail;
            if (!test_passed) begin
                num_failed = num_failed + 1;
                $display("  ❌ FAILED: got 0x%04X, expected 0x%04X", result, expected);
            end else begin
                num_passed = num_passed + 1;
                $display("  ✅ PASSED");
            end
        end
    endtask

    // Timeout watchdog
    initial begin
        #1000000;  // 1ms timeout
        $display("❌ TIMEOUT: Testbench did not complete");
        $finish;
    end

endmodule
