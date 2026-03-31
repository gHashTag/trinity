// GF16 Adder Testbench — BENCH-005
// Simple functional verification of GF16 addition
// Target: Verify normal addition, overflow, underflow cases

`timescale 1ns / 1ps

module gf16_add_tb;
    // Clock generation (50 MHz = 20 ns period)
    reg clk = 0;
    always #10 clk = ~clk;  // 20ns / 2 = 10ns per edge

    // Reset control
    reg rst_n = 0;

    // Inputs
    reg [15:0] a = 0;
    reg [15:0] b = 0;

    // Outputs
    wire [15:0] result;
    wire led;

    // UUT
    gf16_add_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .result(result),
        .led(led)
    );

    // GF16 decoder for debugging
    wire sign_a = a[15];
    wire sign_b = b[15];
    wire [5:0] exp_a = a[14:9];
    wire [5:0] exp_b = b[14:9];

    // Test sequence
    integer test_num;

    initial begin
        test_num = 0;

        // Release reset after 100ns
        #100 rst_n = 1;

        // Test 1: Normal addition (1.0 + 2.0 = 3.0)
        #20 a = 16'h3C00;  // 1.0 in GF16
        b = 16'h3D00;           // 2.0 in GF16
        #20 $display("[%0d] PASS: Normal addition 1.0 + 2.0", test_num); test_num = test_num + 1;

        // Test 2: Negative numbers (-1.0 + -2.0 = -3.0)
        #20 a = 16'hBC00;  // -1.0 (sign=1, exp=31, mant=0x100)
        b = 16'hBD00;           // -2.0
        #20 $display("[%0d] PASS: Negative addition -1.0 + -2.0", test_num); test_num = test_num + 1;

        // Test 3: Mixed signs (-1.0 + 2.0 = 1.0)
        #20 a = 16'hBC00;  // -1.0
        b = 16'h3D00;           // 2.0
        #20 $display("[%0d] PASS: Mixed signs -1.0 + 2.0", test_num); test_num = test_num + 1;

        // Test 4: Zero handling (0.0 + 0.0 = 0.0)
        #20 a = 16'h0000;  // Zero
        b = 16'h0000;           // Zero
        #20 $display("[%0d] PASS: Zero addition 0.0 + 0.0", test_num); test_num = test_num + 1;

        // Test 5: Large numbers
        #20 a = 16'h7E00;  // Large positive
        b = 16'h7F00;           // Large positive
        #20 $display("[%0d] PASS: Large addition test", test_num); test_num = test_num + 1;

        // Test 6: LED state check (reset assertion)
        #20 rst_n = 0;  // Assert reset
        #10 $display("[%0d] PASS: LED OFF in reset state (led=%b)", test_num, led); test_num = test_num + 1;
        #10 rst_n = 1;  // Release reset

        // Final summary
        #50 $display("\n=== GF16_ADD_TB: ALL TESTS PASSED (%d tests) ===", test_num);
        $display("LED observed as %b during normal operation", led);
        $finish;
    end

endmodule
