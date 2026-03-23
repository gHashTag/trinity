//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`timescale 1ns / 1ps

// Test with actual 243x729 parameter WIDTHS but small matrix (6x9)
module ternary_matvec_bram_tb2;

    parameter N_IN  = 6;
    parameter N_OUT = 9;

    reg clk, rst, start;
    wire [19:0] result_data;
    wire [9:0]  result_addr;
    wire        result_valid, done, busy;

    ternary_matvec_bram #(
        .N_IN      (N_IN),
        .N_OUT     (N_OUT),
        .ACC_WIDTH (20),
        .ADDR_WIDTH(18),
        .I_WIDTH   (8),
        .J_WIDTH   (10),
        .MEM_FILE  ("ternary_matvec_6x9_weights.mem")
    ) uut (
        .clk(clk), .rst(rst), .start(start),
        .result_data(result_data), .result_addr(result_addr),
        .result_valid(result_valid), .done(done), .busy(busy)
    );

    always #10 clk = ~clk;

    integer done_seen;
    initial done_seen = 0;

    always @(posedge clk) begin
        if (result_valid)
            $display("y[%0d] = %0d", result_addr, $signed(result_data));
        if (done && !done_seen) begin
            $display("DONE at time %0t", $time);
            done_seen = 1;
        end
    end

    initial begin
        $dumpfile("tb2.vcd");
        $dumpvars(0, ternary_matvec_bram_tb2);

        clk = 0; rst = 1; start = 0;
        #100 rst = 0;
        #40  start = 1;
        #20  start = 0;

        repeat(500) @(posedge clk);

        if (!done_seen) begin
            $display("ERROR: done never asserted!");
            $display("  state=%d busy=%b i_idx=%d j_idx=%d",
                     uut.state, uut.busy, uut.i_idx, uut.j_idx);
        end
        $finish;
    end

endmodule
