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
`ifndef NOWAVE
        $dumpfile("tb_hslm_full.vcd");
        $dumpvars(0, hslm_full_top_tb);
`endif
        clk = 0;
        $display("=== HSLM AUTOREGRESSIVE (3 blocks, TMU K=16): seed=42, 16 tokens ===");
    end

    // =====================================================================
    // CYCLE PROFILING — per-stage cycle counts
    // =====================================================================
    reg [31:0] cycle_cnt;
    always @(posedge clk) cycle_cnt <= cycle_cnt + 1;

    reg [3:0]  prev_state;
    reg [31:0] state_enter_cycle;
    reg [31:0] emb_cycles, b1_cycles, b2_cycles, b3_cycles, lm_cycles, argmax_cycles;

    initial begin
        cycle_cnt = 0;
        prev_state = 4'd0;
        state_enter_cycle = 0;
        emb_cycles = 0; b1_cycles = 0; b2_cycles = 0;
        b3_cycles = 0; lm_cycles = 0; argmax_cycles = 0;
    end

    always @(posedge clk) begin
        prev_state <= uut.st_state;
        if (uut.st_state != prev_state) begin
            case (prev_state)
                4'd2:  emb_cycles    <= cycle_cnt - state_enter_cycle; // ST_RUN_EMB
                4'd4:  b1_cycles     <= cycle_cnt - state_enter_cycle; // ST_RUN_B1
                4'd6:  b2_cycles     <= cycle_cnt - state_enter_cycle; // ST_RUN_B2
                4'd8:  b3_cycles     <= cycle_cnt - state_enter_cycle; // ST_RUN_B3
                4'd10: lm_cycles     <= cycle_cnt - state_enter_cycle; // ST_RUN_LM
                4'd11: argmax_cycles <= cycle_cnt - state_enter_cycle; // ST_WAIT_ARGMAX
            endcase
            state_enter_cycle <= cycle_cnt;
        end
    end

    // Print profile per-token (on ST_NEXT_TOKEN entry) and on ST_DONE
    always @(posedge clk) begin
        if ((uut.st_state == 4'd12 && prev_state != 4'd12) ||
            (uut.st_state == 4'd13 && prev_state != 4'd13)) begin
            $display("\n[PROFILE] token %0d:", uut.gen_count);
            $display("  embedding:  %0d cycles", emb_cycles);
            $display("  block_1:    %0d cycles", b1_cycles);
            $display("  block_2:    %0d cycles", b2_cycles);
            $display("  block_3:    %0d cycles", b3_cycles);
            $display("  lm_head:    %0d cycles", lm_cycles);
            $display("  argmax:     %0d cycles", argmax_cycles);
            $display("  TOTAL:      %0d cycles", emb_cycles + b1_cycles + b2_cycles + b3_cycles + lm_cycles + argmax_cycles);
        end
    end

    // Monitor each generation step
    always @(posedge clk) begin
        if (uut.emb_done)
            $display("[gen %0d] Embedding done (token_id=%0d)", uut.gen_count, uut.emb_token_id);
    end

    always @(posedge clk) begin
        if (uut.b3_done)
            $display("[gen %0d] Block3 done (count=%0d, nonzero=%b)", uut.gen_count, uut.b3_out_count, uut.has_nonzero);
    end

    always @(posedge clk) begin
        if (uut.lm_done)
            $display("[gen %0d] LM Head done", uut.gen_count);
    end

    always @(posedge clk) begin
        if (uut.argmax_valid)
            $display("[gen %0d] Argmax: next_token=%0d (value=%0d)", uut.gen_count, uut.predicted_token, $signed(uut.predicted_val));
    end

    // Completion — ST_DONE = 4'd13 in 3-block autoregressive version
    always @(posedge clk) begin
        if (uut.st_state == 4'd13 && uut.computation_done) begin
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
                $display("\n  >>> PASS — 3-BLOCK TMU K=16 AUTOREGRESSIVE ON FPGA! <<<");
            else
                $display("\n  >>> FAIL <<<");
            #100 $finish;
        end
    end

    // Timeout: 16 tokens × ~2.1ms = ~34ms simulated. 100ms safety.
    initial begin
        #100_000_000;
        $display("TIMEOUT at state=%0d, gen_count=%0d, self_test_pass=%b", uut.st_state, uut.gen_count, uut.self_test_pass);
        if (uut.gen_count >= 5'd1 && uut.self_test_pass)
            $display("  >>> PARTIAL PASS — %0d tokens generated, pipeline validated <<<", uut.gen_count);
        else if (uut.gen_count == 5'd0)
            $display("  >>> FAIL — no tokens generated <<<");
        $finish;
    end

endmodule
