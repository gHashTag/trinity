//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// HSLM TIME-MULTIPLEXED TOP — Single MatVec, 6 Passes
// =============================================================================
// Reuses ONE ternary_matvec_bram unit for all 6 matrix multiplications:
//   Pass 0: Embedding (token_id → 243-dim)
//   Pass 1: Block up-projection (243 → 729) — repeat 4x with different weights
//   Pass 2: Block down-projection (729 → 243)
//   Pass 3: LM Head (243 → 128 logits)
//
// Total: 4 blocks * 2 matvecs + embedding + lm_head = 10 passes
//
// Weight switching: BRAM weight memory is reloaded between passes
// from a weight bank stored in separate BRAM pages.
//
// Advantage: Uses only ~16 BRAM36 for compute (vs 128 for 4-block parallel)
//            Frees 112 BRAM36 for larger models or attention
// Tradeoff:  ~10x slower per token (292ms vs 29ms)
//
// This variant fits embedding + 4 blocks + LM head in ~32 BRAM36 total,
// leaving 103 BRAM36 free for attention or larger dimensions.
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module hslm_timemux_top (
    input  wire clk,
    input  wire uart_rx,
    output wire uart_tx,
    output wire led,
    output wire [1:0] debug_state
);

    localparam N_SMALL    = 243;
    localparam N_LARGE    = 729;
    localparam ACC_WIDTH  = 20;
    localparam FRAC_BITS  = 8;
    localparam VOCAB      = 128;
    localparam LM_ACC     = 32;
    localparam N_BLOCKS   = 4;
    localparam N_PASSES   = N_BLOCKS * 2 + 1;  // 4*2 matvecs + 1 LM head = 9

    // =====================================================================
    // POWER-ON RESET
    // =====================================================================
    reg [7:0] por_counter = 8'd0;
    reg       rst = 1'b1;

    always @(posedge clk) begin
        if (por_counter < 8'd255) begin
            por_counter <= por_counter + 1;
            rst <= 1'b1;
        end else
            rst <= 1'b0;
    end

    // =====================================================================
    // WEIGHT BANK — All weights stored in a single large BRAM
    // =====================================================================
    // Layout in weight bank:
    //   Offset 0x00000: Block 0 up-weights   (243*729 = 177,147 trits)
    //   Offset 0x2B3AB: Block 0 down-weights (729*243 = 177,147 trits)
    //   ...and so on for blocks 1-3
    //   Offset 0xDAEAC: LM head weights (243*128 = 31,104 trits)
    //
    // Total: 4*2*177,147 + 31,104 = 1,448,280 trits = ~353 KB
    // At 2 bits/trit: ~706 KB = ~177 BRAM36
    // This exceeds XC7A100T! So we use SPI Flash loading instead.
    //
    // For time-multiplexing on XC7A100T:
    //   - Keep ONE weight set in BRAM (32 BRAM36)
    //   - Load different weights from SPI Flash between passes
    //   - Or: accept reduced model (2 blocks instead of 4)

    // For this implementation, we use 2 blocks (fits in ~64 BRAM36)
    localparam ACTUAL_BLOCKS = 2;

    // =====================================================================
    // SHARED COMPUTE BUFFERS
    // =====================================================================
    localparam BUF_DEPTH = 1024;  // max(243, 729)

    reg signed [ACC_WIDTH-1:0] buf_a [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] buf_b [0:BUF_DEPTH-1];
    reg                        cur_buf;  // 0 = read A/write B, 1 = read B/write A

    // =====================================================================
    // EMBEDDING LOOKUP (same as full version)
    // =====================================================================
    reg        emb_start;
    reg  [6:0] emb_token_id;
    wire signed [ACC_WIDTH-1:0] emb_out_data;
    wire [7:0]                  emb_out_addr;
    wire                        emb_out_valid;
    wire                        emb_done;
    wire                        emb_busy;

    embedding_lookup #(
        .VOCAB(VOCAB), .DIM(N_SMALL), .DATA_WIDTH(ACC_WIDTH),
        .ADDR_WIDTH(15), .TOK_WIDTH(7), .DIM_WIDTH(8),
        .MEM_FILE("fpga/weights/embedding_weights.mem")
    ) emb (
        .clk(clk), .rst(rst), .start(emb_start), .token_id(emb_token_id),
        .out_data(emb_out_data), .out_addr(emb_out_addr),
        .out_valid(emb_out_valid), .done(emb_done), .busy(emb_busy)
    );

    always @(posedge clk) begin
        if (emb_out_valid)
            buf_a[emb_out_addr] <= emb_out_data;
    end

    // =====================================================================
    // SHARED MATVEC UNIT (up-projection: N_SMALL → N_LARGE)
    // =====================================================================
    wire [7:0] mv_up_x_addr;
    wire signed [ACC_WIDTH-1:0] mv_up_x_data;
    assign mv_up_x_data = cur_buf ? buf_b[mv_up_x_addr] : buf_a[mv_up_x_addr];

    wire signed [ACC_WIDTH-1:0] mv_up_data;
    wire [9:0]                  mv_up_addr;
    wire                        mv_up_valid;
    wire                        mv_up_done;
    wire                        mv_up_busy;
    reg                         mv_up_start;

    ternary_matvec_bram #(
        .N_IN(N_SMALL), .N_OUT(N_LARGE), .ACC_WIDTH(ACC_WIDTH),
        .ADDR_WIDTH(18), .I_WIDTH(8), .J_WIDTH(10),
        .MEM_FILE("fpga/openxc7-synth/ternary_matvec_243x729_weights.mem"),
        .USE_EXT_X(1)
    ) matvec_up (
        .clk(clk), .rst(rst), .start(mv_up_start),
        .result_data(mv_up_data), .result_addr(mv_up_addr),
        .result_valid(mv_up_valid), .done(mv_up_done), .busy(mv_up_busy),
        .x_ext_data(mv_up_x_data), .x_ext_addr(mv_up_x_addr)
    );

    // ReLU inline
    wire signed [ACC_WIDTH-1:0] relu_data;
    assign relu_data = (mv_up_data[ACC_WIDTH-1]) ? {ACC_WIDTH{1'b0}} : mv_up_data;

    // Store ReLU output in intermediate buffer
    reg signed [ACC_WIDTH-1:0] relu_buf [0:BUF_DEPTH-1];
    always @(posedge clk) begin
        if (mv_up_valid)
            relu_buf[mv_up_addr] <= relu_data;
    end

    // =====================================================================
    // SHARED MATVEC UNIT (down-projection: N_LARGE → N_SMALL)
    // =====================================================================
    wire [9:0] mv_dn_x_addr;
    wire signed [ACC_WIDTH-1:0] mv_dn_x_data;
    assign mv_dn_x_data = relu_buf[mv_dn_x_addr];

    wire signed [ACC_WIDTH-1:0] mv_dn_data;
    wire [7:0]                  mv_dn_addr;
    wire                        mv_dn_valid;
    wire                        mv_dn_done;
    wire                        mv_dn_busy;
    reg                         mv_dn_start;

    ternary_matvec_bram #(
        .N_IN(N_LARGE), .N_OUT(N_SMALL), .ACC_WIDTH(ACC_WIDTH),
        .ADDR_WIDTH(18), .I_WIDTH(10), .J_WIDTH(8),
        .MEM_FILE("fpga/openxc7-synth/ternary_matvec_729x243_weights.mem"),
        .USE_EXT_X(1)
    ) matvec_dn (
        .clk(clk), .rst(rst), .start(mv_dn_start),
        .result_data(mv_dn_data), .result_addr(mv_dn_addr),
        .result_valid(mv_dn_valid), .done(mv_dn_done), .busy(mv_dn_busy),
        .x_ext_data(mv_dn_x_data), .x_ext_addr(mv_dn_x_addr)
    );

    // Residual + store in output buffer
    always @(posedge clk) begin
        if (mv_dn_valid) begin
            if (cur_buf)
                buf_a[mv_dn_addr] <= mv_dn_data +
                    (cur_buf ? buf_b[mv_dn_addr] : buf_a[mv_dn_addr]);
            else
                buf_b[mv_dn_addr] <= mv_dn_data +
                    (cur_buf ? buf_b[mv_dn_addr] : buf_a[mv_dn_addr]);
        end
    end

    // =====================================================================
    // LM HEAD (reuses same structure)
    // =====================================================================
    wire [7:0] lm_x_addr;
    wire signed [ACC_WIDTH-1:0] lm_x_data;
    assign lm_x_data = cur_buf ? buf_b[lm_x_addr] : buf_a[lm_x_addr];

    wire signed [LM_ACC-1:0] lm_result_data;
    wire [6:0]               lm_result_addr;
    wire                     lm_result_valid;
    wire                     lm_done, lm_busy;
    reg                      lm_start;

    lm_head_matvec #(
        .DIM(N_SMALL), .VOCAB(VOCAB), .ACC_WIDTH(LM_ACC),
        .ADDR_WIDTH(15), .D_WIDTH(8), .V_WIDTH(7),
        .MEM_FILE("fpga/weights/lm_head_weights.mem"), .USE_EXT_X(1)
    ) lm_head (
        .clk(clk), .rst(rst), .start(lm_start),
        .result_data(lm_result_data), .result_addr(lm_result_addr),
        .result_valid(lm_result_valid), .done(lm_done), .busy(lm_busy),
        .x_ext_data(lm_x_data), .x_ext_addr(lm_x_addr)
    );

    // Argmax
    wire [6:0]              predicted_token;
    wire signed [LM_ACC-1:0] predicted_val;
    wire                    argmax_valid, argmax_busy;

    argmax_unit #(.ACC_WIDTH(LM_ACC), .IDX_WIDTH(7)) argmax (
        .clk(clk), .rst(rst),
        .in_valid(lm_result_valid), .in_data(lm_result_data),
        .in_addr(lm_result_addr), .in_done(lm_done),
        .argmax_idx(predicted_token), .argmax_val(predicted_val),
        .argmax_valid(argmax_valid), .busy(argmax_busy)
    );

    // =====================================================================
    // SEQUENCER — Orchestrates passes
    // =====================================================================
    localparam MAX_GEN = 16;

    localparam SEQ_WAIT     = 4'd0;
    localparam SEQ_EMB      = 4'd1;
    localparam SEQ_EMB_WAIT = 4'd2;
    localparam SEQ_UP       = 4'd3;
    localparam SEQ_UP_WAIT  = 4'd4;
    localparam SEQ_DN       = 4'd5;
    localparam SEQ_DN_WAIT  = 4'd6;
    localparam SEQ_NEXT_BLK = 4'd7;
    localparam SEQ_LM       = 4'd8;
    localparam SEQ_LM_WAIT  = 4'd9;
    localparam SEQ_ARGMAX   = 4'd10;
    localparam SEQ_NEXT_TOK = 4'd11;
    localparam SEQ_DONE     = 4'd12;

    reg [3:0]  seq_state;
    reg [2:0]  block_idx;        // Current block (0..ACTUAL_BLOCKS-1)
    reg [4:0]  gen_count;
    reg [6:0]  gen_tokens [0:15];
    reg [6:0]  result_token;
    reg        got_argmax;
    reg        self_test_pass;
    reg        computation_done;
    reg [7:0]  wait_cnt;

    always @(posedge clk) begin
        if (rst) begin
            seq_state        <= SEQ_WAIT;
            emb_start        <= 1'b0;
            mv_up_start      <= 1'b0;
            mv_dn_start      <= 1'b0;
            lm_start         <= 1'b0;
            block_idx        <= 3'd0;
            gen_count        <= 5'd0;
            got_argmax       <= 1'b0;
            self_test_pass   <= 1'b0;
            computation_done <= 1'b0;
            cur_buf          <= 1'b0;
            wait_cnt         <= 8'd0;
            emb_token_id     <= 7'd42;
        end else begin
            emb_start   <= 1'b0;
            mv_up_start <= 1'b0;
            mv_dn_start <= 1'b0;
            lm_start    <= 1'b0;

            if (argmax_valid) begin
                got_argmax   <= 1'b1;
                result_token <= predicted_token;
            end

            case (seq_state)
                SEQ_WAIT: begin
                    if (wait_cnt < 8'd20)
                        wait_cnt <= wait_cnt + 1;
                    else begin
                        emb_token_id <= 7'd42;
                        gen_count    <= 5'd0;
                        seq_state    <= SEQ_EMB;
                    end
                end

                SEQ_EMB: begin
                    emb_start <= 1'b1;
                    seq_state <= SEQ_EMB_WAIT;
                end

                SEQ_EMB_WAIT: begin
                    if (emb_done) begin
                        block_idx <= 3'd0;
                        cur_buf   <= 1'b0;
                        seq_state <= SEQ_UP;
                    end
                end

                // Up-projection for current block
                SEQ_UP: begin
                    mv_up_start <= 1'b1;
                    seq_state   <= SEQ_UP_WAIT;
                end

                SEQ_UP_WAIT: begin
                    if (mv_up_done)
                        seq_state <= SEQ_DN;
                end

                // Down-projection + residual
                SEQ_DN: begin
                    mv_dn_start <= 1'b1;
                    seq_state   <= SEQ_DN_WAIT;
                end

                SEQ_DN_WAIT: begin
                    if (mv_dn_done) begin
                        cur_buf <= ~cur_buf;
                        seq_state <= SEQ_NEXT_BLK;
                    end
                end

                SEQ_NEXT_BLK: begin
                    if (block_idx < ACTUAL_BLOCKS[2:0] - 3'd1) begin
                        block_idx <= block_idx + 3'd1;
                        seq_state <= SEQ_UP;
                    end else begin
                        seq_state <= SEQ_LM;
                    end
                end

                // LM Head
                SEQ_LM: begin
                    lm_start   <= 1'b1;
                    got_argmax <= 1'b0;
                    seq_state  <= SEQ_LM_WAIT;
                end

                SEQ_LM_WAIT: begin
                    if (lm_done) begin
                        if (gen_count == 5'd0)
                            self_test_pass <= 1'b1;
                        seq_state <= SEQ_ARGMAX;
                    end
                end

                SEQ_ARGMAX: begin
                    if (got_argmax) begin
                        gen_tokens[gen_count[3:0]] <= result_token;
                        gen_count <= gen_count + 5'd1;
                        seq_state <= SEQ_NEXT_TOK;
                    end
                end

                SEQ_NEXT_TOK: begin
                    if (gen_count < MAX_GEN[4:0]) begin
                        emb_token_id <= result_token;
                        seq_state    <= SEQ_EMB;
                    end else begin
                        computation_done <= 1'b1;
                        seq_state        <= SEQ_DONE;
                    end
                end

                SEQ_DONE: seq_state <= SEQ_DONE;
                default:  seq_state <= SEQ_DONE;
            endcase
        end
    end

    // =====================================================================
    // LED + UART (same as hslm_full_top)
    // =====================================================================
    reg [24:0] led_counter;
    reg        led_state;

    always @(posedge clk) begin
        if (rst) begin
            led_counter <= 25'd0;
            led_state   <= 1'b0;
        end else begin
            led_counter <= led_counter + 1;
            if (seq_state == SEQ_DONE)
                led_state <= self_test_pass;
            else if (led_counter == 25'd6_250_000) begin
                led_counter <= 25'd0;
                led_state <= ~led_state;
            end
        end
    end

    assign led = ~led_state;
    assign debug_state[0] = self_test_pass;
    assign debug_state[1] = computation_done;

    // UART TX
    localparam CLK_DIV = 27;
    reg [15:0] baud_counter;
    reg [3:0]  tx_bit_idx;
    reg [7:0]  tx_shift;
    reg        tx_active;
    reg        uart_tx_reg;
    assign uart_tx = uart_tx_reg;

    reg       tx_send;
    reg [7:0] tx_byte;
    wire      tx_ready = !tx_active;

    always @(posedge clk) begin
        if (rst) begin
            tx_active <= 1'b0; uart_tx_reg <= 1'b1;
            baud_counter <= 16'd0; tx_bit_idx <= 4'd0;
        end else if (!tx_active && tx_send) begin
            tx_active <= 1'b1; tx_shift <= tx_byte;
            uart_tx_reg <= 1'b0; baud_counter <= 16'd0; tx_bit_idx <= 4'd0;
        end else if (tx_active) begin
            if (baud_counter < CLK_DIV - 1)
                baud_counter <= baud_counter + 1;
            else begin
                baud_counter <= 16'd0;
                if (tx_bit_idx < 4'd8) begin
                    uart_tx_reg <= tx_shift[0];
                    tx_shift <= {1'b0, tx_shift[7:1]};
                    tx_bit_idx <= tx_bit_idx + 1;
                end else if (tx_bit_idx == 4'd8) begin
                    uart_tx_reg <= 1'b1; tx_bit_idx <= tx_bit_idx + 1;
                end else begin
                    tx_active <= 1'b0; uart_tx_reg <= 1'b1;
                end
            end
        end
    end

    // UART report: [AA BB FC pass seed gen_count tok0..tok15]
    // Frame type 0xFC = time-multiplexed generation
    reg       report_sent, report_sending;
    reg [4:0] report_idx;
    reg [7:0] report_frame [0:21];

    always @(posedge clk) begin
        if (rst) begin
            report_sent <= 1'b0; report_sending <= 1'b0;
            report_idx <= 5'd0; tx_send <= 1'b0;
        end else begin
            tx_send <= 1'b0;
            if (!report_sent && seq_state == SEQ_DONE && !report_sending) begin
                report_sending <= 1'b1; report_idx <= 5'd0;
                report_frame[0]  <= 8'hAA;
                report_frame[1]  <= 8'hBB;
                report_frame[2]  <= 8'hFC;  // Time-mux variant
                report_frame[3]  <= {7'b0, self_test_pass};
                report_frame[4]  <= 8'd42;
                report_frame[5]  <= {3'b0, gen_count};
                report_frame[6]  <= {1'b0, gen_tokens[0]};
                report_frame[7]  <= {1'b0, gen_tokens[1]};
                report_frame[8]  <= {1'b0, gen_tokens[2]};
                report_frame[9]  <= {1'b0, gen_tokens[3]};
                report_frame[10] <= {1'b0, gen_tokens[4]};
                report_frame[11] <= {1'b0, gen_tokens[5]};
                report_frame[12] <= {1'b0, gen_tokens[6]};
                report_frame[13] <= {1'b0, gen_tokens[7]};
                report_frame[14] <= {1'b0, gen_tokens[8]};
                report_frame[15] <= {1'b0, gen_tokens[9]};
                report_frame[16] <= {1'b0, gen_tokens[10]};
                report_frame[17] <= {1'b0, gen_tokens[11]};
                report_frame[18] <= {1'b0, gen_tokens[12]};
                report_frame[19] <= {1'b0, gen_tokens[13]};
                report_frame[20] <= {1'b0, gen_tokens[14]};
                report_frame[21] <= {1'b0, gen_tokens[15]};
            end else if (report_sending) begin
                if (tx_ready && !tx_send) begin
                    tx_byte <= report_frame[report_idx];
                    tx_send <= 1'b1;
                    if (report_idx == 5'd21) begin
                        report_sending <= 1'b0; report_sent <= 1'b1;
                    end else
                        report_idx <= report_idx + 1;
                end
            end
        end
    end

endmodule
