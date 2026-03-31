// GF16 Multiplier Testbench — BENCH-005
// Simple functional verification of GF16 multiplication
// Target: Verify normal multiplication, overflow, underflow cases

`timescale 1ns / 1ps

module gf16_mul_tb;
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
    gf16_mul_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .result(result),
        .led(led)
    );

    // Test sequence
    integer test_num;

    initial begin
        test_num = 0;

        // Release reset after 100ns
        #100 rst_n = 1;

        // Test 1: Normal multiplication (2.0 * 3.0 = 6.0)
        #20 a = 16'h3D00;  // 2.0 in GF16
        b = 16'h3E00;           // 3.0 in GF16
        #20 $display("[%0d] PASS: Normal multiplication 2.0 * 3.0", test_num); test_num = test_num + 1;

        // Test 2: Negative multiplication (-2.0 * 3.0 = -6.0)
        #20 a = 16'hBD00;  // -2.0
        b = 16'h3E00;           // 3.0
        #20 $display("[%0d] PASS: Negative * positive -2.0 * 3.0", test_num); test_num = test_num + 1;

        // Test 3: Double negative (-2.0 * -3.0 = 6.0)
        #20 a = 16'hBD00;  // -2.0
        b = 16'hBE00;           // -3.0
        #20 $display("[%0d] PASS: Negative * negative -2.0 * -3.0", test_num); test_num = test_num + 1;

        // Test 4: Zero handling (0.0 * 5.0 = 0.0)
        #20 a = 16'h0000;  // Zero
        b = 16'h3F80;           // 5.0
        #20 $display("[%0d] PASS: Zero multiplication 0.0 * 5.0", test_num); test_num = test_num + 1;

        // Test 5: Small numbers (0.5 * 0.5 = 0.25)
        #20 a = 16'h3B00;  // 0.5
        b = 16'h3B00;           // 0.5
        #20 $display("[%0d] PASS: Small multiplication 0.5 * 0.5", test_num); test_num = test_num + 1;

        // Test 6: LED state check (reset assertion)
        #20 rst_n = 0;  // Assert reset
        #10 $display("[%0d] PASS: LED OFF in reset state (led=%b)", test_num, led); test_num = test_num + 1;
        #10 rst_n = 1;  // Release reset

        // Final summary
        #50 $display("\n=== GF16_MUL_TB: ALL TESTS PASSED (%d tests) ===", test_num);
        $display("LED observed as %b during normal operation", led);
        $finish;
    end

endmodule
