//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// Minimal TF3 test - just verify basic functionality
`timescale 1ns / 1ps

module tf3_minimal;

    reg clk;
    reg rst;
    reg [1:0] a_sign;
    reg [1:0] b_sign;

    wire signed [2:0] add_sign_ext;
    wire [1:0]       add_result_sign;
    wire              add_sign_carry;

    // Ternary addition
    assign {add_sign_carry, add_sign_ext[1:0]} = (a_sign + b_sign) + 2'sd01;

    // Saturating: -1, 0, +1 only
    assign add_result_sign =
        (add_sign_ext > 2'sd01) ? 2'b10 :
        (add_sign_ext < 2'sd11) ? 2'b01 :
        2'sd00;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;

        $display("\nTF3 Minimal Test");

        @(posedge clk);
        rst = 1;
        @(posedge clk);
        rst = 0;

        // Test: 0 + 0 = 0
        @(posedge clk);
        a_sign = 2'b00;
        b_sign = 2'b00;

        #10;
        $display("Test 0+0: a_sign=%b, b_sign=%b, result=%b (expected 00)",
                 a_sign, b_sign, add_result_sign);

        // Test: +1 + 0 = +1
        @(posedge clk);
        a_sign = 2'b10;
        b_sign = 2'b00;

        #10;
        $display("Test +1+0: a_sign=%b, b_sign=%b, result=%b (expected 10)",
                 a_sign, b_sign, add_result_sign);

        // Test: -1 + 0 = -1
        @(posedge clk);
        a_sign = 2'b01;
        b_sign = 2'b00;

        #10;
        $display("Test -1+0: a_sign=%b, b_sign=%b, result=%b (expected 01)",
                 a_sign, b_sign, add_result_sign);

        // Test: +1 + (-1) = 0
        @(posedge clk);
        a_sign = 2'b10;
        b_sign = 2'b01;

        #10;
        $display("Test +1-1: a_sign=%b, b_sign=%b, result=%b (expected 00)",
                 a_sign, b_sign, add_result_sign);

        #100;
        $display("\nTest complete");
        $finish;
    end

endmodule
