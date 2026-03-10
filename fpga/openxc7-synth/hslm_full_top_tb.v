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
        $display("=== HSLM FULL PIPELINE: Token -> Embedding -> 4 Blocks -> LM Head -> Argmax ===");
        $display("  Self-test token_id = 42");
    end

    // Monitor embedding
    always @(posedge clk) begin
        if (uut.emb_done)
            $display("  Embedding done (token_id=%0d)", uut.emb_token_id);
    end

    // Monitor blocks
    always @(posedge clk) begin
        if (uut.b1_done) $display("  Block1 done");
        if (uut.b2_done) $display("  Block2 done");
        if (uut.b3_done) $display("  Block3 done");
        if (uut.b4_done) $display("  Block4 done (count=%0d, nonzero=%b)", uut.b4_out_count, uut.has_nonzero);
    end

    // Monitor LM Head (128 logits)
    integer lm_count;
    initial lm_count = 0;

    always @(posedge clk) begin
        if (uut.lm_result_valid) begin
            if (lm_count < 5)
                $display("  logit[%0d] = %0d", uut.lm_result_addr, $signed(uut.lm_result_data));
            if (lm_count == 5)
                $display("  ... (skipping remaining logits) ...");
            lm_count = lm_count + 1;
        end

        if (uut.lm_done)
            $display("  LM Head done (%0d logits emitted)", lm_count);
    end

    // Monitor argmax
    always @(posedge clk) begin
        if (uut.argmax_valid) begin
            $display("  Argmax: token=%0d, value=%0d", uut.predicted_token, $signed(uut.predicted_val));
        end
    end

    // Completion check
    always @(posedge clk) begin
        if (uut.st_state == 4'd13 && uut.computation_done) begin
            $display("\n=== RESULT ===");
            $display("  self_test_pass = %b", uut.self_test_pass);
            $display("  input_token    = %0d", uut.emb_token_id);
            $display("  output_token   = %0d (argmax)", uut.result_token);
            $display("  b4_out_count   = %0d (expected 243)", uut.b4_out_count);
            $display("  Block4 results[0..7]:");
            $display("    [0]=%0d [1]=%0d [2]=%0d [3]=%0d",
                $signed(uut.uart_results[0]), $signed(uut.uart_results[1]),
                $signed(uut.uart_results[2]), $signed(uut.uart_results[3]));
            $display("    [4]=%0d [5]=%0d [6]=%0d [7]=%0d",
                $signed(uut.uart_results[4]), $signed(uut.uart_results[5]),
                $signed(uut.uart_results[6]), $signed(uut.uart_results[7]));
            if (uut.self_test_pass)
                $display("  >>> PASS — FULL PIPELINE ON FPGA! D6 ON <<<");
            else
                $display("  >>> FAIL <<<");
            #100 $finish;
        end
    end

    // 4 blocks × ~7.2 ms + embedding ~5us + lm_head ~1.3ms = ~30 ms → 45 ms timeout
    initial begin
        #45_000_000_000;
        $display("TIMEOUT at state=%0d", uut.st_state);
        $finish;
    end

endmodule
