//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// Simple TF3 test
// Tests trit addition without clocked logic
`timescale 1ns / 1ps

module tf3_simple;

    reg [1:0] a_sign;
    reg [1:0] b_sign;

    wire signed [2:0] add_sign_ext;
    wire [1:0]       add_result_sign;
    wire              add_sign_carry;

    // Ternary addition
    assign {add_sign_carry, add_sign_ext[1:0]} = (a_sign + b_sign) + 2'sd01;

    // Saturating: -1, 0, +1 only
    // add_sign_ext range check: <0 = -1, >1 = +1, else = 0
    assign add_result_sign =
        (add_sign_ext > 3'sd001) ? 2'b10 :   // +1
        (add_sign_ext < 3'sd000) ? 2'b01 :   // -1
        2'b000;                                // 0

    initial begin
        $display("\n========================================");
        $display("  TF3 Simple Trit Test");
        $display("========================================\n");

        // Initialize inputs
        a_sign = 2'b00;
        b_sign = 2'b00;

        // Test 1: 0 + 0 = 0
        $display("\nTest 1: 0 + 0 = 0");
        a_sign = 2'b00;
        b_sign = 2'b00;
        #1;
        $display("  a_sign=%b, b_sign=%b, result=%b (expected 00) - %s",
                 a_sign, b_sign, add_result_sign,
                 (add_result_sign == 2'b00) ? "PASS" : "FAIL");

        // Test 2: +1 + 0 = +1
        $display("\nTest 2: +1 + 0 = +1");
        a_sign = 2'b10;
        b_sign = 2'b00;
        #1;
        $display("  a_sign=%b, b_sign=%b, result=%b (expected 10) - %s",
                 a_sign, b_sign, add_result_sign,
                 (add_result_sign == 2'b10) ? "PASS" : "FAIL");

        // Test 3: -1 + 0 = -1
        $display("\nTest 3: -1 + 0 = -1");
        a_sign = 2'b01;
        b_sign = 2'b00;
        #1;
        $display("  a_sign=%b, b_sign=%b, result=%b (expected 01) - %s",
                 a_sign, b_sign, add_result_sign,
                 (add_result_sign == 2'b01) ? "PASS" : "FAIL");

        // Test 4: +1 + (-1) = 0
        $display("\nTest 4: +1 + (-1) = 0");
        a_sign = 2'b10;
        b_sign = 2'b01;
        #1;
        $display("  a_sign=%b, b_sign=%b, result=%b (expected 00) - %s",
                 a_sign, b_sign, add_result_sign,
                 (add_result_sign == 2'b00) ? "PASS" : "FAIL");

        // Test 5: +1 + +1 = +1 (saturates)
        $display("\nTest 5: +1 + +1 = +1 (saturate)");
        a_sign = 2'b10;
        b_sign = 2'b10;
        #1;
        $display("  a_sign=%b, b_sign=%b, result=%b (expected 10) - %s",
                 a_sign, b_sign, add_result_sign,
                 (add_result_sign == 2'b10) ? "PASS" : "FAIL");

        // Test 6: -1 + (-1) = -1 (saturates)
        $display("\nTest 6: -1 + (-1) = -1 (saturate)");
        a_sign = 2'b01;
        b_sign = 2'b01;
        #1;
        $display("  a_sign=%b, b_sign=%b, result=%b (expected 01) - %s",
                 a_sign, b_sign, add_result_sign,
                 (add_result_sign == 2'b01) ? "PASS" : "FAIL");

        #100;
        $finish;
    end

endmodule
