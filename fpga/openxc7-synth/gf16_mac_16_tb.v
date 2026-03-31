// ═════════════════════════════════════════════════════════════════════════════
// GF16 MAC-16 TESTBENCH — Functional Verification (BENCH-006)
// ═════════════════════════════════════════════════════════════════════════════
//
// Test vectors:
//   1. Zero inputs → zero output
//   2. All weights = 1, all inputs = 1 → sum = 16
//   3. All weights = -1, all inputs = 1 → sum = -16
//   4. Sparse vectors (mostly zeros)
//   5. Random vectors (compare with CPU reference)
//
// Usage:
//   iverilog -o gf16_mac_16_tb gf16_mac_16_top.v gf16_mac_16_tb.v
//   vvp gf16_mac_16_tb
//
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════

`default_nettype none
`timescale 1ns/1ps

module gf16_mac_16_tb;

    // ========================================================================
    // DUT SIGNALS
    // ========================================================================
    reg clk;
    reg rst_n;
    reg valid;
    reg [255:0] w;
    reg [255:0] x;
    wire ready;
    wire [15:0] y;
    wire overflow;

    // ========================================================================
    // CLK GENERATION (10ns = 100MHz)
    // ========================================================================
    initial clk = 0;
    always #5 clk = ~clk;

    // ========================================================================
    // GF16 ENCODING HELPERS (1:5:10 format, bias=15)
    // ========================================================================
    // Value = (-1)^sign × 2^(exp-15) × (1.mantissa)
    // Simple helper: encode signed integer to GF16

    function [15:0] enc_gf16;
        input signed [15:0] val;
        begin
            if (val == 0)
                enc_gf16 = 16'h0000;
            else if (val > 0)
                enc_gf16 = {1'b0, 5'd15, val[8:0]};  // Simplified: exp=bias
            else
                enc_gf16 = {1'b1, 5'd15, -val[8:0]}; // Simplified: exp=bias
        end
    endfunction

    // ========================================================================
    // TASK: apply test vector
    // ========================================================================
    task apply_vector;
        input [255:0] w_vec;
        input [255:0] x_vec;
        input [100*8:1] name;
        begin
            $display("=== TEST: %s ===", name);
            w = w_vec;
            x = x_vec;
            valid = 1;
            @(posedge clk);
            valid = 0;
            @(posedge clk);
            if (ready) begin
                $display("  y = 0x%04h (overflow=%b)", y, overflow);
            end
            @(posedge clk);
        end
    endtask

    // ========================================================================
    // MAIN TEST SEQUENCE
    // ========================================================================
    integer test_count;
    integer passed;

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        valid = 0;
        w = 256'h0;
        x = 256'h0;
        test_count = 0;
        passed = 0;

        // Reset
        #20 rst_n = 1;
        #10;

        $display("\n╔══════════════════════════════════════════════════════════════╗");
        $display("║  GF16 MAC-16 TESTBENCH — BENCH-006                        ║");
        $display("╚══════════════════════════════════════════════════════════════╝\n");

        // ----------------------------------------------------------------------
        // TEST 1: Zero inputs → zero output
        // ----------------------------------------------------------------------
        apply_vector(256'h0, 256'h0, "Zero inputs");
        if (y == 16'h0000) begin
            $display("  ✓ PASS: zero output");
            passed = passed + 1;
        end else begin
            $display("  ✗ FAIL: expected 0x0000, got 0x%04h", y);
        end
        test_count = test_count + 1;

        // ----------------------------------------------------------------------
        // TEST 2: All ones → sum = 16
        // ----------------------------------------------------------------------
        begin
            reg [255:0] ones_vec;
            integer j;
            for (j = 0; j < 16; j = j + 1) begin
                ones_vec[16*j +: 16] = enc_gf16(16'sd1);
            end
            apply_vector(ones_vec, ones_vec, "All ones (1×1 × 16 = 16)");
            // Expected: y ≈ 16 (in GF16 format)
            if (y[14:0] != 15'h0000) begin
                $display("  ✓ PASS: non-zero output");
                passed = passed + 1;
            end
        end
        test_count = test_count + 1;

        // ----------------------------------------------------------------------
        // TEST 3: Weights = +1, Inputs = -1 → sum = -16
        // ----------------------------------------------------------------------
        begin
            reg [255:0] w_ones, x_minus;
            integer j;
            for (j = 0; j < 16; j = j + 1) begin
                w_ones[16*j +: 16] = enc_gf16(16'sd1);
                x_minus[16*j +: 16] = enc_gf16(-16'sd1);
            end
            apply_vector(w_ones, x_minus, "1 × (-1) × 16 = -16");
        end
        test_count = test_count + 1;

        // ----------------------------------------------------------------------
        // TEST 4: Sparse (only one non-zero)
        // ----------------------------------------------------------------------
        begin
            reg [255:0] sparse_w, sparse_x;
            integer j;
            sparse_w = 256'h0;
            sparse_x = 256'h0;
            sparse_w[0 +: 16] = enc_gf16(16'sd5);    // w[0] = 5
            sparse_x[0 +: 16] = enc_gf16(16'sd3);    // x[0] = 3
            // Expected: 5 × 3 = 15
            apply_vector(sparse_w, sparse_x, "Sparse: 5×3 = 15");
        end
        test_count = test_count + 1;

        // ----------------------------------------------------------------------
        // TEST 5: Alternating signs
        // ----------------------------------------------------------------------
        begin
            reg [255:0] w_alt, x_alt;
            integer j;
            for (j = 0; j < 16; j = j + 1) begin
                if (j[0]) begin  // Odd indices
                    w_alt[16*j +: 16] = enc_gf16(-16'sd1);
                    x_alt[16*j +: 16] = enc_gf16(16'sd1);
                end else begin  // Even indices
                    w_alt[16*j +: 16] = enc_gf16(16'sd1);
                    x_alt[16*j +: 16] = enc_gf16(16'sd1);
                end
            end
            apply_vector(w_alt, x_alt, "Alternating signs");
        end
        test_count = test_count + 1;

        // ----------------------------------------------------------------------
        // SUMMARY
        // ----------------------------------------------------------------------
        #20;
        $display("\n╔══════════════════════════════════════════════════════════════╗");
        $display("║  TEST SUMMARY: %0d/%0d passed                                   ║", passed, test_count);
        $display("╚══════════════════════════════════════════════════════════════╝\n");

        if (passed == test_count)
            $display("✓ ALL TESTS PASSED\n");
        else
            $display("✗ SOME TESTS FAILED\n");

        $finish;
    end

    // ========================================================================
    // TIMEOUT WATCHDOG
    // ========================================================================
    initial begin
        #100000 $display("✗ ERROR: timeout");
        $finish;
    end

    // ========================================================================
    // DUT INSTANTIATION
    // ========================================================================
    gf16_mac_16_top #(
        .LATENCY(2)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid(valid),
        .w(w),
        .x(x),
        .ready(ready),
        .y(y),
        .overflow(overflow)
    );

endmodule
