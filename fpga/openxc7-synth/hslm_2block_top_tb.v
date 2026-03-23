//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`timescale 1ns / 1ps

module hslm_2block_top_tb;

    reg clk;
    wire uart_tx, led;
    wire [1:0] debug_state;

    hslm_2block_top uut (
        .clk(clk), .uart_rx(1'b1), .uart_tx(uart_tx),
        .led(led), .debug_state(debug_state)
    );

    always #10 clk = ~clk;

    initial begin
        $dumpfile("tb_hslm_2block.vcd");
        $dumpvars(0, hslm_2block_top_tb);
        clk = 0;
        $display("=== HSLM 2-BLOCK: Two Stacked TrinityBlocks ===");
    end

    // Track Block1 progress
    always @(posedge clk) begin
        if (uut.b1_done)
            $display("  Block1 done — output captured to inter_buffer");
    end

    // Track Block2 output
    integer b2_count;
    initial b2_count = 0;

    always @(posedge clk) begin
        if (uut.b2_out_valid) begin
            if (b2_count < 9)
                $display("  b2_out: k=%0d data=%0d", uut.b2_out_addr, $signed(uut.b2_out_data));
            if (b2_count == 9)
                $display("  ... (skipping) ...");
            b2_count = b2_count + 1;
        end

        if (uut.b2_done) begin
            $display("\nBlock2 done! b2_out_count=%0d has_nonzero=%b",
                uut.b2_out_count, uut.has_nonzero);
        end

        if (uut.st_state == 4'd6 && uut.computation_done) begin
            $display("\n=== RESULT ===");
            $display("  self_test_pass = %b", uut.self_test_pass);
            $display("  b2_out_count = %0d (expected 243)", uut.b2_out_count);
            $display("  has_nonzero = %b", uut.has_nonzero);
            $display("  Final results[0..7] (after Block2 RMSNorm):");
            $display("    [0]=%0d [1]=%0d [2]=%0d [3]=%0d",
                $signed(uut.uart_results[0]), $signed(uut.uart_results[1]),
                $signed(uut.uart_results[2]), $signed(uut.uart_results[3]));
            $display("    [4]=%0d [5]=%0d [6]=%0d [7]=%0d",
                $signed(uut.uart_results[4]), $signed(uut.uart_results[5]),
                $signed(uut.uart_results[6]), $signed(uut.uart_results[7]));
            if (uut.self_test_pass)
                $display("  >>> PASS — HSLM 2-BLOCK ON FPGA! D6 ON <<<");
            else
                $display("  >>> FAIL — D6 will be OFF <<<");
            #100 $finish;
        end
    end

    // Timeout: 2 blocks × ~7.2 ms = ~14.4 ms = ~720K clocks × 20ns = ~14.4M ns
    // Use 20 ms = 20_000_000 ns with margin
    initial begin
        #20_000_000_000;
        $display("TIMEOUT at state=%0d b1_done=%b b2_done=%b",
            uut.st_state, uut.b1_done, uut.b2_done);
        $finish;
    end

endmodule
