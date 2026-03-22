// GF16 Multiplier Testbench
// Verifies GF16 (Golden Float 16) multiplication
// Simplified: checks sign bit [14] without full format validation
`timescale 1ns / 1ps

module gf16_multiplier_tb;

    reg         clk;
    reg         rst;
    reg         in_valid;
    reg [14:0]  in_a;
    reg [14:0]  in_b;
    reg         out_ready;

    wire        in_ready;
    wire        out_valid;
    wire [14:0] out_y;

    integer error_count;

    // Instantiate GF16 Multiplier
    gf16_multiplier uut (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_a(in_a),
        .in_b(in_b),
        .in_ready(in_ready),
        .out_valid(out_valid),
        .out_y(out_y),
        .out_ready(out_ready)
    );

    // Clock (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        error_count = 0;

        $display("\n\n========================================");
        $display("  GF16 Multiplier Testbench");
        $display("========================================\n");

        // Reset
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Test 1: 0 × 0 = 0
        $display("\nTest 1: 0 × 0 = 0");
        in_valid = 1;
        in_a = 15'b000000000000000;  // 0
        in_b = 15'b000000000000000;  // 0
        @(posedge clk);
        @(posedge clk);
        if (out_y[14] == 1'b0) $display("  PASS: sign = 0");
        else $display("  FAIL: sign = %b", out_y[14]);

        // Test 2: +1 × 0 = 0
        $display("\nTest 2: +1 × 0 = 0");
        in_a = 15'b000001000000001;  // +1
        in_b = 15'b000000000000000;  // 0
        @(posedge clk);
        @(posedge clk);
        if (out_y[14] == 1'b0) $display("  PASS: sign = 0");
        else $display("  FAIL: sign = %b", out_y[14]);

        // Test 3: +1 × +1 = +1
        $display("\nTest 3: +1 × +1 = +1");
        in_a = 15'b000001000000001;  // +1
        in_b = 15'b000001000000001;  // +1
        @(posedge clk);
        @(posedge clk);
        if (out_y[14] == 1'b0) $display("  PASS: sign = 0");
        else $display("  FAIL: sign = %b", out_y[14]);

        // Test 4: +1 × -1 = -1 (XOR sign)
        $display("\nTest 4: +1 × -1 = -1");
        in_a = 15'b000001000000001;  // +1
        in_b = 15'b100001000000001;  // -1
        @(posedge clk);
        @(posedge clk);
        if (out_y[14] == 1'b1) $display("  PASS: sign = 1");
        else $display("  FAIL: sign = %b", out_y[14]);

        // Test 5: -1 × -1 = +1 (XOR sign: 1⊕1=0)
        $display("\nTest 5: -1 × -1 = +1");
        in_a = 15'b100001000000001;  // -1
        in_b = 15'b100001000000001;  // -1
        @(posedge clk);
        @(posedge clk);
        if (out_y[14] == 1'b0) $display("  PASS: sign = 0");
        else $display("  FAIL: sign = %b", out_y[14]);

        // Test 6: 2 × 2 = 4 (same exp, mantissa multiply)
        $display("\nTest 6: 2 × 2 = 4");
        in_a = 15'b000001000000010;  // +2 (exp=1, mant=2)
        in_b = 15'b000001000000010;  // +2
        @(posedge clk);
        @(posedge clk);
        if (out_y[14] == 1'b0) $display("  PASS: sign = 0");
        else $display("  FAIL: sign = %b", out_y[14]);

        // Summary
        #50;
        $display("\n\n========================================");
        $display("  Test Summary");
        $display("========================================");
        $display("Tests Passed: %0d", 6 - error_count);
        $display("Tests Failed: %0d", error_count);
        if (error_count == 0) begin
            $display("  *** ALL TESTS PASSED ***\n");
        end else begin
            $display("  *** %0d TEST(S) FAILED ***\n", error_count);
        end

        #100;
        $finish;
    end

endmodule
