//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// Simple TF3 add test
`timescale 1ns / 1ps

module tf3_simple_test;
    reg         clk;
    reg         rst;

    reg [1:0]  mode;
    reg         in_valid;
    reg [17:0] in_a;
    reg [17:0] in_b;
    wire        in_ready;
    wire        out_valid;
    wire [17:0] out_y;
    reg         out_ready;

    integer test_num;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;

        test_num = 0;
        $display("\n\n========================================");
        $display("  TF3 ALU Simple Test");
        $display("========================================\n");
        $display("Testing: result_reg assignment");

        @(posedge clk);
        rst = 1;
        @(posedge clk);
        rst = 0;

        @(posedge clk);
        mode = 2'b00;
        in_a = 18'b1000000000000000001;  // +1
        in_b = 18'b0000000000000000000;  // 0
        in_valid = 1;
        out_ready = 0;

        @(posedge clk);
        while (!in_ready) begin
            @(posedge clk);
        end

        @(posedge clk);
        in_valid = 0;

        @(posedge clk);
        out_ready = 1;

        while (!out_valid) begin
            @(posedge clk);
            end

        @(posedge clk);
        // Wait for result
        #10;
        @(posedge clk);
        out_ready = 0;
        while (!out_valid) begin
                @(posedge clk);
            end

        // Check result
        $display("[%0t] result_reg = 0x%h, out_y = 0x%h", $time, 18'b0000000000000000000, out_y);
        if (out_y !== 18'b0000000000000000000) begin
            $display("FAIL!");
        end

        #100;
        $finish;
    end

endmodule
