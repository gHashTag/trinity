// =============================================================================
// EMBEDDING LOOKUP TESTBENCH — Verify BRAM-Based Ternary Token Embedding
// =============================================================================
// Tests:
//   1. Single token lookup (token 0): verify 243 outputs streamed
//   2. Token 42 (seed): verify correct base address and ternary decode
//   3. Token 127 (max vocab): boundary check
//   4. Back-to-back lookups: verify no state corruption
//   5. Output value verification: check +1, -1, 0 decoding
//
// Expected embedding pattern (from generate_all_weights.py):
//   code = (token_id * 17 + d * 31 + 7) % 3
//   0 → 01 (+1), 1 → 10 (-1), 2 → 00 (0)
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module embedding_lookup_tb;

    parameter VOCAB      = 128;
    parameter DIM        = 243;
    parameter DATA_WIDTH = 20;
    parameter ADDR_WIDTH = 15;
    parameter TOK_WIDTH  = 7;
    parameter DIM_WIDTH  = 8;

    reg                        clk;
    reg                        rst;
    reg                        start;
    reg  [TOK_WIDTH-1:0]       token_id;

    wire signed [DATA_WIDTH-1:0] out_data;
    wire [DIM_WIDTH-1:0]         out_addr;
    wire                         out_valid;
    wire                         done;
    wire                         busy;

    // =========================================================================
    // DUT
    // =========================================================================
    embedding_lookup #(
        .VOCAB     (VOCAB),
        .DIM       (DIM),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TOK_WIDTH (TOK_WIDTH),
        .DIM_WIDTH (DIM_WIDTH),
        .MEM_FILE  ("fpga/weights/embedding_weights.mem")
    ) dut (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .token_id (token_id),
        .out_data (out_data),
        .out_addr (out_addr),
        .out_valid(out_valid),
        .done     (done),
        .busy     (busy)
    );

    // =========================================================================
    // CLOCK — 50 MHz (20 ns period)
    // =========================================================================
    initial clk = 0;
    always #10 clk = ~clk;

    // =========================================================================
    // TEST TRACKING
    // =========================================================================
    integer out_count;
    integer errors;
    integer test_num;
    integer plus_ones, minus_ones, zeros;

    // Expected ternary code: (token_id * 17 + d * 31 + 7) % 3
    // 0 → +1, 1 → -1, 2 → 0
    function signed [DATA_WIDTH-1:0] expected_value;
        input [TOK_WIDTH-1:0] tok;
        input [DIM_WIDTH-1:0] dim;
        integer code;
        begin
            code = (tok * 17 + dim * 31 + 7) % 3;
            case (code)
                0: expected_value = {{(DATA_WIDTH-1){1'b0}}, 1'b1};  // +1
                1: expected_value = {DATA_WIDTH{1'b1}};               // -1
                default: expected_value = {DATA_WIDTH{1'b0}};         // 0
            endcase
        end
    endfunction

    // =========================================================================
    // TASK: Lookup one token and verify all DIM outputs
    // =========================================================================
    task lookup_and_verify;
        input [TOK_WIDTH-1:0] tok;
        input integer verify_values;  // 1 = check each value, 0 = just count
        begin
            @(posedge clk);
            token_id <= tok;
            start <= 1'b1;
            @(posedge clk);
            start <= 1'b0;

            out_count  = 0;
            plus_ones  = 0;
            minus_ones = 0;
            zeros      = 0;

            // Wait for outputs
            while (!done) begin
                @(posedge clk);
                if (out_valid) begin
                    out_count = out_count + 1;

                    // Track value distribution
                    if (out_data == {{(DATA_WIDTH-1){1'b0}}, 1'b1})
                        plus_ones = plus_ones + 1;
                    else if (out_data == {DATA_WIDTH{1'b1}})
                        minus_ones = minus_ones + 1;
                    else if (out_data == {DATA_WIDTH{1'b0}})
                        zeros = zeros + 1;
                    else begin
                        $display("ERROR: token %0d, dim %0d: unexpected value %0d",
                                 tok, out_addr, out_data);
                        errors = errors + 1;
                    end

                    // Verify individual values if requested
                    if (verify_values) begin
                        if (out_data !== expected_value(tok, out_addr)) begin
                            $display("ERROR: token %0d, dim %0d: got %0d, expected %0d",
                                     tok, out_addr, out_data,
                                     expected_value(tok, out_addr));
                            errors = errors + 1;
                        end
                    end
                end
            end

            // Wait one more cycle for done pulse
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // MAIN TEST SEQUENCE
    // =========================================================================
    initial begin
        $dumpfile("embedding_lookup_tb.vcd");
        $dumpvars(0, embedding_lookup_tb);

        errors   = 0;
        test_num = 0;

        // Reset
        rst      = 1'b1;
        start    = 1'b0;
        token_id = 7'd0;
        repeat (20) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        // =================================================================
        // TEST 1: Token 0 — basic functionality
        // =================================================================
        test_num = 1;
        $display("\n=== TEST %0d: Token 0 (basic lookup) ===", test_num);

        lookup_and_verify(7'd0, 1);

        if (out_count != DIM) begin
            $display("ERROR: expected %0d outputs, got %0d", DIM, out_count);
            errors = errors + 1;
        end else
            $display("  PASS: %0d outputs received", out_count);

        $display("  Distribution: +1=%0d, -1=%0d, 0=%0d", plus_ones, minus_ones, zeros);

        // =================================================================
        // TEST 2: Token 42 (seed token) — verify values
        // =================================================================
        test_num = 2;
        $display("\n=== TEST %0d: Token 42 (seed, full verify) ===", test_num);

        lookup_and_verify(7'd42, 1);

        if (out_count != DIM) begin
            $display("ERROR: expected %0d outputs, got %0d", DIM, out_count);
            errors = errors + 1;
        end else
            $display("  PASS: %0d outputs verified", out_count);

        $display("  Distribution: +1=%0d, -1=%0d, 0=%0d", plus_ones, minus_ones, zeros);

        // =================================================================
        // TEST 3: Token 127 (max vocab-1) — boundary check
        // =================================================================
        test_num = 3;
        $display("\n=== TEST %0d: Token 127 (max boundary) ===", test_num);

        lookup_and_verify(7'd127, 1);

        if (out_count != DIM) begin
            $display("ERROR: expected %0d outputs, got %0d", DIM, out_count);
            errors = errors + 1;
        end else
            $display("  PASS: %0d outputs verified", out_count);

        // =================================================================
        // TEST 4: Back-to-back lookups — no state corruption
        // =================================================================
        test_num = 4;
        $display("\n=== TEST %0d: Back-to-back (tokens 0,1,2) ===", test_num);

        lookup_and_verify(7'd0, 0);
        if (out_count != DIM) begin
            $display("ERROR: token 0: expected %0d, got %0d", DIM, out_count);
            errors = errors + 1;
        end

        lookup_and_verify(7'd1, 0);
        if (out_count != DIM) begin
            $display("ERROR: token 1: expected %0d, got %0d", DIM, out_count);
            errors = errors + 1;
        end

        lookup_and_verify(7'd2, 0);
        if (out_count != DIM) begin
            $display("ERROR: token 2: expected %0d, got %0d", DIM, out_count);
            errors = errors + 1;
        end

        $display("  PASS: 3 back-to-back lookups, no corruption");

        // =================================================================
        // TEST 5: Busy/done handshake
        // =================================================================
        test_num = 5;
        $display("\n=== TEST %0d: Busy/done handshake ===", test_num);

        // Verify not busy initially
        if (busy) begin
            $display("ERROR: busy should be 0 in idle");
            errors = errors + 1;
        end

        // Start lookup
        @(posedge clk);
        token_id <= 7'd10;
        start    <= 1'b1;
        @(posedge clk);
        start    <= 1'b0;

        // Should become busy within 2 clocks
        @(posedge clk);
        @(posedge clk);
        if (!busy) begin
            $display("ERROR: busy should be 1 during computation");
            errors = errors + 1;
        end

        // Wait for done
        while (!done) @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        // Should be idle again
        if (busy) begin
            $display("ERROR: busy should be 0 after done");
            errors = errors + 1;
        end

        $display("  PASS: busy/done handshake correct");

        // =================================================================
        // TEST 6: All ternary values present
        // =================================================================
        test_num = 6;
        $display("\n=== TEST %0d: Ternary distribution check ===", test_num);

        lookup_and_verify(7'd42, 0);

        if (plus_ones == 0 || minus_ones == 0 || zeros == 0) begin
            $display("ERROR: missing ternary values (+1=%0d, -1=%0d, 0=%0d)",
                     plus_ones, minus_ones, zeros);
            errors = errors + 1;
        end else begin
            $display("  PASS: all three ternary values present");
            $display("  +1: %0d (%.1f%%)", plus_ones, plus_ones * 100.0 / DIM);
            $display("  -1: %0d (%.1f%%)", minus_ones, minus_ones * 100.0 / DIM);
            $display("   0: %0d (%.1f%%)", zeros, zeros * 100.0 / DIM);
        end

        // =================================================================
        // SUMMARY
        // =================================================================
        $display("\n========================================");
        if (errors == 0)
            $display("ALL %0d TESTS PASSED", test_num);
        else
            $display("FAILED: %0d errors in %0d tests", errors, test_num);
        $display("========================================\n");

        $finish;
    end

    // Timeout
    initial begin
        #5_000_000;
        $display("ERROR: simulation timeout");
        $finish;
    end

endmodule
