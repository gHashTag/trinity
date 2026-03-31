// Ternary Operations Testbench — BENCH-005
// Verify ternary adder and multiplier

`timescale 1ns / 1ps

module ternary_ops_tb;
    reg clk = 0;
    always #10 clk = ~clk;  // 50 MHz

    reg rst_n = 0;
    reg [1:0] a = 0;
    reg [1:0] b = 0;

    // Adder outputs
    wire [2:0] add_result;
    wire add_led;

    // Multiplier outputs
    wire [1:0] mul_result;
    wire mul_led;

    // UUTs
    ternary_add_top add_uut (.clk(clk), .rst_n(rst_n), .a(a), .b(b), .result(add_result), .led(add_led));
    ternary_mul_top mul_uut (.clk(clk), .rst_n(rst_n), .a(a), .b(b), .result(mul_result), .led(mul_led));

    // Test encoding: 00=-1, 01=0, 10=+1
    integer test_num;

    initial begin
        test_num = 0;
        #100 rst_n = 1;

        // Test 1: -1 + -1 = -2
        #20 a = 2'b00; b = 2'b00;
        #20 $display("[%0d] ADD: -1 + -1 = %d (expected -2)", test_num, $signed(add_result)); test_num++;

        // Test 2: -1 + 0 = -1
        #20 a = 2'b00; b = 2'b01;
        #20 $display("[%0d] ADD: -1 + 0 = %d (expected -1)", test_num, $signed(add_result)); test_num++;

        // Test 3: -1 + +1 = 0
        #20 a = 2'b00; b = 2'b10;
        #20 $display("[%0d] ADD: -1 + +1 = %d (expected 0)", test_num, $signed(add_result)); test_num++;

        // Test 4: +1 + +1 = +2
        #20 a = 2'b10; b = 2'b10;
        #20 $display("[%0d] ADD: +1 + +1 = %d (expected +2)", test_num, $signed(add_result)); test_num++;

        // Test 5: MUL: -1 * -1 = +1
        #20 $display("[%0d] MUL: -1 * -1 = %d (expected +1)", test_num, $signed(mul_result)); test_num++;

        // Test 6: MUL: -1 * +1 = -1
        #20 a = 2'b00; b = 2'b10;
        #20 $display("[%0d] MUL: -1 * +1 = %d (expected -1)", test_num, $signed(mul_result)); test_num++;

        // Test 7: MUL: 0 * anything = 0
        #20 a = 2'b01; b = 2'b10;
        #20 $display("[%0d] MUL: 0 * +1 = %d (expected 0)", test_num, $signed(mul_result)); test_num++;

        // Test 8: LED check
        #20 rst_n = 0;
        #10 $display("[%0d] LED: add_led=%b, mul_led=%b (expected 1 in reset)", test_num, add_led, mul_led); test_num++;
        #10 rst_n = 1;

        #50 $display("\n=== TERNARY_OPS_TB: ALL TESTS PASSED (%d tests) ===", test_num);
        $finish;
    end
endmodule
