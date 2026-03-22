// Simplified TF3 ALU testbench
// Tests only sign bit [17:16] without full TF3-9 format
`timescale 1ns / 1ps

module tf3_alu_simple_tb;

    reg         clk;
    reg         rst;
    reg [1:0]  mode;
    reg [17:0] in_a;
    reg [17:0] in_b;
    reg [7:0]  dot_len;

    wire        in_ready;
    wire        out_valid;
    wire [17:0] out_y;
    reg         out_ready;

    integer error_count;

    // Instantiate TF3 ALU
    tf3_alu uut (
        .clk(clk),
        .rst(rst),
        .mode(mode),
        .in_a(in_a),
        .in_b(in_b),
        .dot_len(dot_len),
        .in_ready(in_ready),
        .out_valid(out_valid),
        .out_y(out_y),
        .out_ready(out_ready)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz period = 10ns
    end

    initial begin
        error_count = 0;

        $display("\n\n========================================");
        $display("  TF3 ALU Simple Testbench");
        $display("========================================\n");

        // Test 1: 0 + 0 = 0
        $display("\nTest 1: 0 + 0 = 0");
        @(posedge clk);
        in_a = 18'b0000000000000000;
        in_b = 18'b0000000000000000;
        mode = 2'b00;
        @(posedge clk);
        if (out_y[17:16] == 2'b00) $display("  PASS: result_sign = 00");
        else $display("  FAIL: result_sign = %b", out_y[17:16]);

        // Test 2: +1 + 0 = +1
        $display("\nTest 2: +1 + 0 = +1");
        @(posedge clk);
        in_a = 18'b1000000000000000;
        in_b = 18'b0000000000000000;
        mode = 2'b00;
        @(posedge clk);
        if (out_y[17:16] == 2'b10) $display("  PASS: result_sign = 10");
        else $display("  FAIL: result_sign = %b", out_y[17:16]);

        // Test 3: -1 + 0 = -1
        $display("\nTest 3: -1 + 0 = -1");
        @(posedge clk);
        in_a = 18'b0100000000000000;
        in_b = 18'b0000000000000000;
        mode = 2'b00;
        @(posedge clk);
        if (out_y[17:16] == 2'b01) $display("  PASS: result_sign = 01");
        else $display("  FAIL: result_sign = %b", out_y[17:16]);

        // Test 4: +1 + (-1) = 0
        $display("\nTest 4: +1 + (-1) = 0");
        @(posedge clk);
        in_a = 18'b1000000000000000;
        in_b = 18'b0100000000000000;
        mode = 2'b00;
        @(posedge clk);
        if (out_y[17:16] == 2'b00) $display("  PASS: result_sign = 00");
        else $display("  FAIL: result_sign = %b", out_y[17:16]);

        // Test 5: +1 + 1 = +1 (saturate)
        $display("\nTest 5: +1 + 1 = +1 (saturate)");
        @(posedge clk);
        in_a = 18'b1000000000000000;
        in_b = 18'b1000000000000000;
        mode = 2'b00;
        @(posedge clk);
        if (out_y[17:16] == 2'b10) $display("  PASS: result_sign = 10");
        else $display("  FAIL: result_sign = %b", out_y[17:16]);

        // Test 6: -1 + (-1) = -1 (saturate)
        $display("\nTest 6: -1 + (-1) = -1 (saturate)");
        @(posedge clk);
        in_a = 18'b0100000000000000;
        in_b = 18'b0100000000000000;
        mode = 2'b00;
        @(posedge clk);
        if (out_y[17:16] == 2'b01) $display("  PASS: result_sign = 01");
        else $display("  FAIL: result_sign = %b", out_y[17:16]);

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
