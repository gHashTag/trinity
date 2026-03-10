`timescale 1ns / 1ps

module hslm_full_top_tb;

    reg clk;
    wire uart_tx, led;
    wire [1:0] debug_state;

    hslm_full_top uut (
        .clk(clk), .uart_rx(1'b1), .uart_tx(uart_tx),
        .led(led), .debug_state(debug_state)
    );

    always #10 clk = ~clk;

    initial begin
        $dumpfile("tb_hslm_full.vcd");
        $dumpvars(0, hslm_full_top_tb);
        clk = 0;
        $display("=== HSLM AUTOREGRESSIVE: seed=42, 16 tokens ===");
    end

    // Monitor each generation step
    always @(posedge clk) begin
        if (uut.emb_done)
            $display("[gen %0d] Embedding done (token_id=%0d)", uut.gen_count, uut.emb_token_id);
    end

    always @(posedge clk) begin
        if (uut.b4_done)
            $display("[gen %0d] Block4 done (count=%0d, nonzero=%b)", uut.gen_count, uut.b4_out_count, uut.has_nonzero);
    end

    always @(posedge clk) begin
        if (uut.lm_done)
            $display("[gen %0d] LM Head done", uut.gen_count);
    end

    always @(posedge clk) begin
        if (uut.argmax_valid)
            $display("[gen %0d] Argmax: next_token=%0d (value=%0d)", uut.gen_count, uut.predicted_token, $signed(uut.predicted_val));
    end

    // Completion — ST_DONE = 4'd15 in autoregressive version
    always @(posedge clk) begin
        if (uut.st_state == 4'd15 && uut.computation_done) begin
            $display("\n=== AUTOREGRESSIVE GENERATION COMPLETE ===");
            $display("  self_test_pass = %b", uut.self_test_pass);
            $display("  seed_token     = 42");
            $display("  tokens_generated = %0d", uut.gen_count);
            $display("  Generated sequence:");
            $display("    [0]=%0d [1]=%0d [2]=%0d [3]=%0d",
                uut.gen_tokens[0], uut.gen_tokens[1],
                uut.gen_tokens[2], uut.gen_tokens[3]);
            $display("    [4]=%0d [5]=%0d [6]=%0d [7]=%0d",
                uut.gen_tokens[4], uut.gen_tokens[5],
                uut.gen_tokens[6], uut.gen_tokens[7]);
            $display("    [8]=%0d [9]=%0d [10]=%0d [11]=%0d",
                uut.gen_tokens[8], uut.gen_tokens[9],
                uut.gen_tokens[10], uut.gen_tokens[11]);
            $display("    [12]=%0d [13]=%0d [14]=%0d [15]=%0d",
                uut.gen_tokens[12], uut.gen_tokens[13],
                uut.gen_tokens[14], uut.gen_tokens[15]);
            if (uut.self_test_pass)
                $display("\n  >>> PASS — AUTOREGRESSIVE GENERATION ON FPGA! <<<");
            else
                $display("\n  >>> FAIL <<<");
            #100 $finish;
        end
    end

    // Timeout: 16 tokens × ~30ms = ~480ms → 600ms safety
    initial begin
        #600_000_000_000;
        $display("TIMEOUT at state=%0d, gen_count=%0d", uut.st_state, uut.gen_count);
        $finish;
    end

endmodule
