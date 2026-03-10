`timescale 1ns / 1ps

module hslm_3block_top_tb;

    reg clk;
    wire uart_tx, led;
    wire [1:0] debug_state;

    hslm_3block_top uut (
        .clk(clk), .uart_rx(1'b1), .uart_tx(uart_tx),
        .led(led), .debug_state(debug_state)
    );

    always #10 clk = ~clk;

    initial begin
        $dumpfile("tb_hslm_3block.vcd");
        $dumpvars(0, hslm_3block_top_tb);
        clk = 0;
        $display("=== HSLM 3-BLOCK: Three Stacked TrinityBlocks ===");
    end

    always @(posedge clk) begin
        if (uut.b1_done) $display("  Block1 done");
        if (uut.b2_done) $display("  Block2 done");
    end

    integer b3_count;
    initial b3_count = 0;

    always @(posedge clk) begin
        if (uut.b3_out_valid) begin
            if (b3_count < 9)
                $display("  b3_out: k=%0d data=%0d", uut.b3_out_addr, $signed(uut.b3_out_data));
            if (b3_count == 9)
                $display("  ... (skipping) ...");
            b3_count = b3_count + 1;
        end

        if (uut.b3_done)
            $display("\nBlock3 done! b3_out_count=%0d has_nonzero=%b",
                uut.b3_out_count, uut.has_nonzero);

        if (uut.st_state == 4'd8 && uut.computation_done) begin
            $display("\n=== RESULT ===");
            $display("  self_test_pass = %b", uut.self_test_pass);
            $display("  b3_out_count = %0d (expected 243)", uut.b3_out_count);
            $display("  Final results[0..7]:");
            $display("    [0]=%0d [1]=%0d [2]=%0d [3]=%0d",
                $signed(uut.uart_results[0]), $signed(uut.uart_results[1]),
                $signed(uut.uart_results[2]), $signed(uut.uart_results[3]));
            $display("    [4]=%0d [5]=%0d [6]=%0d [7]=%0d",
                $signed(uut.uart_results[4]), $signed(uut.uart_results[5]),
                $signed(uut.uart_results[6]), $signed(uut.uart_results[7]));
            if (uut.self_test_pass)
                $display("  >>> PASS — HSLM 3-BLOCK ON FPGA! D6 ON <<<");
            else
                $display("  >>> FAIL <<<");
            #100 $finish;
        end
    end

    // 3 blocks × ~7.2 ms = ~21.6 ms → 30 ms timeout
    initial begin
        #30_000_000_000;
        $display("TIMEOUT at state=%0d", uut.st_state);
        $finish;
    end

endmodule
