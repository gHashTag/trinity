`timescale 1ns / 1ps

module ternary_matvec_bram_tb;

    parameter N_IN  = 4;
    parameter N_OUT = 4;

    reg clk, rst, start;
    wire [19:0] result_data;
    wire [1:0]  result_addr;
    wire        result_valid, done, busy;

    ternary_matvec_bram #(
        .N_IN      (N_IN),
        .N_OUT     (N_OUT),
        .ACC_WIDTH (20),
        .ADDR_WIDTH(4),
        .I_WIDTH   (2),
        .J_WIDTH   (2),
        .MEM_FILE  ("ternary_matvec_4x4_weights.mem")
    ) uut (
        .clk(clk), .rst(rst), .start(start),
        .result_data(result_data), .result_addr(result_addr),
        .result_valid(result_valid), .done(done), .busy(busy)
    );

    always #10 clk = ~clk;

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, ternary_matvec_bram_tb);

        clk = 0; rst = 1; start = 0;
        #100 rst = 0;
        #40  start = 1;
        #20  start = 0;

        // Wait for done
        repeat(200) @(posedge clk);

        if (!done) begin
            $display("ERROR: done never asserted after 200 clocks!");
            $display("  state=%d busy=%b i_idx=%d j_idx=%d",
                     uut.state, uut.busy, uut.i_idx, uut.j_idx);
        end

        $finish;
    end

    always @(posedge clk) begin
        if (result_valid)
            $display("y[%0d] = %0d (signed: %0d)", result_addr, result_data, $signed(result_data));
        if (done)
            $display("DONE at time %0t", $time);
    end

endmodule
