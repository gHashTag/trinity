//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// Simple TF3 trit addition test
// Tests just the trit addition logic without full TF3-9 complexity
`timescale 1ns / 1ps

module tf3_add_test;

    reg clk;
    reg rst;
    reg in_valid;
    reg [17:0] in_a;
    reg [17:0] in_b;
    wire in_ready;
    wire out_valid;
    wire [17:0] out_y;
    reg out_ready;

    integer test_num;
    integer error_count;

    // Trit decode function
    function [1:0] trit_decode;
        input [1:0] t;
        begin
            case (t)
                2'b00: trit_decode = 2'b00;  // 0
                2'b01: trit_decode = 2'b11;  // -1
                2'b10: trit_decode = 2'b01;  // +1
                default: trit_decode = 2'b00;
            endcase
        end
    endfunction

    // Sign wires (decoded)
    wire signed [1:0] a_sign;
    wire signed [1:0] b_sign;

    // Decode signs
    assign a_sign = (in_a[17:16] == 2'b10) ? 2'sd01 :
                   (in_a[17:16] == 2'b01) ? 2'sd11 :
                   2'sd00;

    assign b_sign = (in_b[17:16] == 2'b10) ? 2'sd01 :
                   (in_b[17:16] == 2'b01) ? 2'sd11 :
                   2'sd00;

    // Add sign with saturating ternary arithmetic
    wire signed [2:0] add_sign_ext;
    wire [1:0]       add_result_sign;
    wire              add_sign_carry;

    assign {add_sign_carry, add_sign_ext[1:0]} = (a_sign + b_sign) + 2'sd01;

    // Saturating result: -1, 0, +1 only
    assign add_result_sign =
        (add_sign_ext > 2'sd01) ? 2'b10 :  // +1
        (add_sign_ext < 2'sd11) ? 2'b01 :  // -1
        2'sd00;                               // 0

    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz

        test_num = 0;
        error_count = 0;

        $display("\n\n========================================");
        $display("  TF3 Trit Addition Test");
        $display("========================================\n");

        // Reset
        @(posedge clk);
        rst = 1;
        @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Test 1: 0 + 0 = 0
        test_num = 1;
        $display("\nTest %0d: 0 + 0", test_num);
        in_a = 18'b0000000000000000000;  // sign=00
        in_b = 18'b0000000000000000000;
        in_valid = 1;
        out_ready = 0;

        @(posedge clk);
        while (!in_ready) @(posedge clk);
        @(posedge clk);
        in_valid = 0;

        @(posedge clk);
        out_ready = 1;
        while (!out_valid) @(posedge clk);

        if (out_y[17:16] !== 2'b00) begin
            $display("FAIL: Expected sign=00, got sign=%b", out_y[17:16]);
            error_count = error_count + 1;
        end else begin
            $display("PASS: Result=0");
        end

        #10;
        out_ready = 0;

        // Test 2: +1 + 0 = +1
        test_num = 2;
        $display("\nTest %0d: +1 + 0", test_num);
        in_a = 18'b1000000000000000000;  // sign=10 (+1)
        in_b = 18'b0000000000000000000;
        in_valid = 1;
        out_ready = 0;

        @(posedge clk);
        while (!in_ready) @(posedge clk);
        @(posedge clk);
        in_valid = 0;

        @(posedge clk);
        out_ready = 1;
        while (!out_valid) @(posedge clk);

        if (out_y[17:16] !== 2'b10) begin
            $display("FAIL: Expected sign=10, got sign=%b", out_y[17:16]);
            error_count = error_count + 1;
        end else begin
            $display("PASS: Result=+1");
        end

        #10;
        out_ready = 0;

        // Test 3: -1 + 0 = -1
        test_num = 3;
        $display("\nTest %0d: -1 + 0", test_num);
        in_a = 18'b0100000000000000000;  // sign=01 (-1)
        in_b = 18'b0000000000000000000;
        in_valid = 1;
        out_ready = 0;

        @(posedge clk);
        while (!in_ready) @(posedge clk);
        @(posedge clk);
        in_valid = 0;

        @(posedge clk);
        out_ready = 1;
        while (!out_valid) @(posedge clk);

        if (out_y[17:16] !== 2'b01) begin
            $display("FAIL: Expected sign=01, got sign=%b", out_y[17:16]);
            error_count = error_count + 1;
        end else begin
            $display("PASS: Result=-1");
        end

        #10;
        out_ready = 0;

        // Test 4: +1 + (-1) = 0 (cancel)
        test_num = 4;
        $display("\nTest %0d: +1 + (-1) = 0", test_num);
        in_a = 18'b1000000000000000000;  // sign=10 (+1)
        in_b = 18'b0100000000000000000;  // sign=01 (-1)
        in_valid = 1;
        out_ready = 0;

        @(posedge clk);
        while (!in_ready) @(posedge clk);
        @(posedge clk);
        in_valid = 0;

        @(posedge clk);
        out_ready = 1;
        while (!out_valid) @(posedge clk);

        if (out_y[17:16] !== 2'b00) begin
            $display("FAIL: Expected sign=00, got sign=%b", out_y[17:16]);
            error_count = error_count + 1;
        end else begin
            $display("PASS: Result=0");
        end

        // Summary
        #50;
        $display("\n\n========================================");
        $display("  Test Summary");
        $display("========================================");
        $display("Tests Passed: %0d", 4 - error_count);
        $display("Tests Failed: %0d", error_count);

        if (error_count == 0)
            $display("\n*** ALL TESTS PASSED ***\n");
        else
            $display("\n*** %0d TEST(S) FAILED ***\n", error_count);

        #100;
        $finish;
    end

endmodule
