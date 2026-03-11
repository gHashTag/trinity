// =============================================================================
// HSLM UART INFERENCE TOP — Host-Controlled Ternary Transformer
// =============================================================================
// Receives token_id via UART, runs full inference pipeline, returns result.
// This enables the Zig↔FPGA end-to-end demo:
//   Zig host → UART → FPGA inference → UART → Zig output
//
// Protocol (Host → FPGA):
//   [SYNC=0xAA][CMD][DATA...]
//
// Commands:
//   0x10 INFER_TOKEN  [token_id]                    → run inference, return predicted token
//   0x11 INFER_SEQ    [seed_token][n_tokens]         → autoregressive generation
//   0x12 GET_STATUS                                  → return pipeline status
//   0x13 LOAD_WEIGHTS [block_id][addr_h][addr_l][len][data...]  → dynamic weight load
//
// Response (FPGA → Host):
//   [SYNC=0xAA][RESP_CODE][DATA...]
//   0x80 INFER_RESULT  [predicted_token][latency_h][latency_l]
//   0x81 SEQ_RESULT    [n_tokens][tok0..tokN]
//   0x82 STATUS        [state][blocks_done][pass]
//   0x83 ACK           — command acknowledged
//   0xFF ERROR         [error_code]
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module hslm_uart_inference_top (
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
    localparam CLK_DIV    = 27;  // 115200 baud @ 50MHz

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
    // UART RX
    // =====================================================================
    reg [1:0]  rx_state;
    reg [15:0] rx_clk_div;
    reg [3:0]  rx_bit_cnt;
    reg [7:0]  rx_shift;
    reg [3:0]  rx_sample_cnt;
    reg        rx_valid;
    reg [7:0]  rx_byte;

    localparam RX_IDLE  = 2'b00;
    localparam RX_START = 2'b01;
    localparam RX_DATA  = 2'b10;
    localparam RX_STOP  = 2'b11;

    always @(posedge clk) begin
        if (rst) begin
            rx_state      <= RX_IDLE;
            rx_valid      <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            case (rx_state)
                RX_IDLE: begin
                    if (!uart_rx) begin
                        rx_state      <= RX_START;
                        rx_clk_div    <= 16'd0;
                        rx_sample_cnt <= 4'd0;
                    end
                end
                RX_START: begin
                    if (rx_clk_div == CLK_DIV - 1) begin
                        rx_clk_div <= 16'd0;
                        if (rx_sample_cnt == 4'd7) begin
                            if (!uart_rx) begin rx_state <= RX_DATA; rx_bit_cnt <= 4'd0; end
                            else rx_state <= RX_IDLE;
                        end else
                            rx_sample_cnt <= rx_sample_cnt + 1'b1;
                    end else
                        rx_clk_div <= rx_clk_div + 1'b1;
                end
                RX_DATA: begin
                    if (rx_clk_div == CLK_DIV - 1) begin
                        rx_clk_div <= 16'd0;
                        if (rx_sample_cnt == 4'd15) begin
                            rx_shift <= {uart_rx, rx_shift[7:1]};
                            if (rx_bit_cnt == 4'd7) rx_state <= RX_STOP;
                            else rx_bit_cnt <= rx_bit_cnt + 1'b1;
                            rx_sample_cnt <= 4'd0;
                        end else
                            rx_sample_cnt <= rx_sample_cnt + 1'b1;
                    end else
                        rx_clk_div <= rx_clk_div + 1'b1;
                end
                RX_STOP: begin
                    if (rx_clk_div == CLK_DIV - 1) begin
                        rx_byte  <= rx_shift;
                        rx_valid <= 1'b1;
                        rx_state <= RX_IDLE;
                    end else
                        rx_clk_div <= rx_clk_div + 1'b1;
                end
            endcase
        end
    end

    // =====================================================================
    // UART TX
    // =====================================================================
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

    // =====================================================================
    // COMMAND PARSER
    // =====================================================================
    localparam SYNC_BYTE       = 8'hAA;
    localparam CMD_INFER_TOKEN = 8'h10;
    localparam CMD_INFER_SEQ   = 8'h11;
    localparam CMD_GET_STATUS  = 8'h12;

    localparam RESP_INFER      = 8'h80;
    localparam RESP_SEQ        = 8'h81;
    localparam RESP_STATUS     = 8'h82;
    localparam RESP_ERROR      = 8'hFF;

    localparam P_SYNC = 3'd0;
    localparam P_CMD  = 3'd1;
    localparam P_ARG0 = 3'd2;
    localparam P_ARG1 = 3'd3;

    reg [2:0] parse_state;
    reg [7:0] cmd_reg;
    reg [6:0] cmd_token_id;
    reg [7:0] cmd_n_tokens;

    reg       start_single_infer;
    reg       start_seq_infer;
    reg       start_status;

    always @(posedge clk) begin
        if (rst) begin
            parse_state       <= P_SYNC;
            start_single_infer <= 1'b0;
            start_seq_infer   <= 1'b0;
            start_status      <= 1'b0;
        end else begin
            start_single_infer <= 1'b0;
            start_seq_infer   <= 1'b0;
            start_status      <= 1'b0;

            if (rx_valid) begin
                case (parse_state)
                    P_SYNC: begin
                        if (rx_byte == SYNC_BYTE)
                            parse_state <= P_CMD;
                    end

                    P_CMD: begin
                        cmd_reg <= rx_byte;
                        case (rx_byte)
                            CMD_INFER_TOKEN: parse_state <= P_ARG0;
                            CMD_INFER_SEQ:   parse_state <= P_ARG0;
                            CMD_GET_STATUS: begin
                                start_status <= 1'b1;
                                parse_state  <= P_SYNC;
                            end
                            default: parse_state <= P_SYNC;
                        endcase
                    end

                    P_ARG0: begin
                        cmd_token_id <= rx_byte[6:0];
                        if (cmd_reg == CMD_INFER_TOKEN) begin
                            start_single_infer <= 1'b1;
                            parse_state        <= P_SYNC;
                        end else begin
                            parse_state <= P_ARG1;
                        end
                    end

                    P_ARG1: begin
                        cmd_n_tokens <= rx_byte;
                        start_seq_infer <= 1'b1;
                        parse_state     <= P_SYNC;
                    end

                    default: parse_state <= P_SYNC;
                endcase
            end
        end
    end

    // =====================================================================
    // INFERENCE PIPELINE (reuse from hslm_full_top)
    // =====================================================================
    localparam BUF_DEPTH = 256;

    reg signed [ACC_WIDTH-1:0] emb_buffer [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] inter_buf1 [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] inter_buf2 [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] inter_buf3 [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] b4_output_buf [0:BUF_DEPTH-1];

    // Embedding
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
        if (emb_out_valid) emb_buffer[emb_out_addr] <= emb_out_data;
    end

    // Block 1
    wire [7:0] b1_rd_addr;
    assign b1_rd_data = emb_buffer[b1_rd_addr];
    wire signed [ACC_WIDTH-1:0] b1_rd_data;
    wire b1_out_valid, b1_busy, b1_done;
    wire signed [ACC_WIDTH-1:0] b1_out_data;
    wire [7:0] b1_out_addr;
    reg b1_start;

    trinity_block #(
        .N_SMALL(N_SMALL), .N_LARGE(N_LARGE), .ACC_WIDTH(ACC_WIDTH),
        .FRAC_BITS(FRAC_BITS), .ADDR_WIDTH(18),
        .I_UP_WIDTH(8), .J_UP_WIDTH(10), .I_DOWN_WIDTH(10), .J_DOWN_WIDTH(8),
        .MEM_FILE_UP("fpga/openxc7-synth/ternary_matvec_243x729_weights.mem"),
        .MEM_FILE_DOWN("fpga/openxc7-synth/ternary_matvec_729x243_weights.mem")
    ) block1 (
        .clk(clk), .rst(rst), .start(b1_start),
        .x_rd_addr(b1_rd_addr), .x_rd_data(b1_rd_data),
        .out_valid(b1_out_valid), .out_data(b1_out_data), .out_addr(b1_out_addr),
        .busy(b1_busy), .done(b1_done)
    );

    always @(posedge clk) begin
        if (b1_out_valid) inter_buf1[b1_out_addr] <= b1_out_data;
    end

    // Block 2
    wire [7:0] b2_rd_addr;
    assign b2_rd_data = inter_buf1[b2_rd_addr];
    wire signed [ACC_WIDTH-1:0] b2_rd_data;
    wire b2_out_valid, b2_busy, b2_done;
    wire signed [ACC_WIDTH-1:0] b2_out_data;
    wire [7:0] b2_out_addr;
    reg b2_start;

    trinity_block #(
        .N_SMALL(N_SMALL), .N_LARGE(N_LARGE), .ACC_WIDTH(ACC_WIDTH),
        .FRAC_BITS(FRAC_BITS), .ADDR_WIDTH(18),
        .I_UP_WIDTH(8), .J_UP_WIDTH(10), .I_DOWN_WIDTH(10), .J_DOWN_WIDTH(8),
        .MEM_FILE_UP("fpga/openxc7-synth/ternary_matvec_b2_243x729_weights.mem"),
        .MEM_FILE_DOWN("fpga/openxc7-synth/ternary_matvec_b2_729x243_weights.mem")
    ) block2 (
        .clk(clk), .rst(rst), .start(b2_start),
        .x_rd_addr(b2_rd_addr), .x_rd_data(b2_rd_data),
        .out_valid(b2_out_valid), .out_data(b2_out_data), .out_addr(b2_out_addr),
        .busy(b2_busy), .done(b2_done)
    );

    always @(posedge clk) begin
        if (b2_out_valid) inter_buf2[b2_out_addr] <= b2_out_data;
    end

    // Block 3
    wire [7:0] b3_rd_addr;
    assign b3_rd_data = inter_buf2[b3_rd_addr];
    wire signed [ACC_WIDTH-1:0] b3_rd_data;
    wire b3_out_valid, b3_busy, b3_done;
    wire signed [ACC_WIDTH-1:0] b3_out_data;
    wire [7:0] b3_out_addr;
    reg b3_start;

    trinity_block #(
        .N_SMALL(N_SMALL), .N_LARGE(N_LARGE), .ACC_WIDTH(ACC_WIDTH),
        .FRAC_BITS(FRAC_BITS), .ADDR_WIDTH(18),
        .I_UP_WIDTH(8), .J_UP_WIDTH(10), .I_DOWN_WIDTH(10), .J_DOWN_WIDTH(8),
        .MEM_FILE_UP("fpga/openxc7-synth/ternary_matvec_b3_243x729_weights.mem"),
        .MEM_FILE_DOWN("fpga/openxc7-synth/ternary_matvec_b3_729x243_weights.mem")
    ) block3 (
        .clk(clk), .rst(rst), .start(b3_start),
        .x_rd_addr(b3_rd_addr), .x_rd_data(b3_rd_data),
        .out_valid(b3_out_valid), .out_data(b3_out_data), .out_addr(b3_out_addr),
        .busy(b3_busy), .done(b3_done)
    );

    always @(posedge clk) begin
        if (b3_out_valid) inter_buf3[b3_out_addr] <= b3_out_data;
    end

    // Block 4
    wire [7:0] b4_rd_addr;
    assign b4_rd_data = inter_buf3[b4_rd_addr];
    wire signed [ACC_WIDTH-1:0] b4_rd_data;
    wire b4_out_valid, b4_busy, b4_done;
    wire signed [ACC_WIDTH-1:0] b4_out_data;
    wire [7:0] b4_out_addr;
    reg b4_start;

    trinity_block #(
        .N_SMALL(N_SMALL), .N_LARGE(N_LARGE), .ACC_WIDTH(ACC_WIDTH),
        .FRAC_BITS(FRAC_BITS), .ADDR_WIDTH(18),
        .I_UP_WIDTH(8), .J_UP_WIDTH(10), .I_DOWN_WIDTH(10), .J_DOWN_WIDTH(8),
        .MEM_FILE_UP("fpga/openxc7-synth/ternary_matvec_b4_243x729_weights.mem"),
        .MEM_FILE_DOWN("fpga/openxc7-synth/ternary_matvec_b4_729x243_weights.mem")
    ) block4 (
        .clk(clk), .rst(rst), .start(b4_start),
        .x_rd_addr(b4_rd_addr), .x_rd_data(b4_rd_data),
        .out_valid(b4_out_valid), .out_data(b4_out_data), .out_addr(b4_out_addr),
        .busy(b4_busy), .done(b4_done)
    );

    always @(posedge clk) begin
        if (b4_out_valid) b4_output_buf[b4_out_addr] <= b4_out_data;
    end

    // LM Head
    wire [7:0] lm_x_addr;
    wire signed [ACC_WIDTH-1:0] lm_x_data_raw;
    assign lm_x_data_raw = b4_output_buf[lm_x_addr];

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
        .x_ext_data(lm_x_data_raw), .x_ext_addr(lm_x_addr)
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
    // INFERENCE CONTROL FSM
    // =====================================================================
    localparam MAX_GEN = 32;  // Max tokens for sequence generation

    localparam INF_IDLE       = 5'd0;
    localparam INF_START_EMB  = 5'd1;
    localparam INF_RUN_EMB   = 5'd2;
    localparam INF_START_B1   = 5'd3;
    localparam INF_RUN_B1    = 5'd4;
    localparam INF_START_B2   = 5'd5;
    localparam INF_RUN_B2    = 5'd6;
    localparam INF_START_B3   = 5'd7;
    localparam INF_RUN_B3    = 5'd8;
    localparam INF_START_B4   = 5'd9;
    localparam INF_RUN_B4    = 5'd10;
    localparam INF_START_LM   = 5'd11;
    localparam INF_RUN_LM    = 5'd12;
    localparam INF_WAIT_ARG  = 5'd13;
    localparam INF_GOT_TOKEN = 5'd14;
    localparam INF_NEXT_SEQ  = 5'd15;
    localparam INF_SEND_RESP = 5'd16;
    localparam INF_SEND_STATUS = 5'd17;

    reg [4:0]  inf_state;
    reg        inf_is_seq;         // 1 = sequence mode, 0 = single token
    reg [7:0]  inf_n_tokens;       // Target token count for sequence
    reg [7:0]  inf_gen_count;      // Tokens generated so far
    reg [6:0]  inf_result_token;
    reg        inf_got_argmax;
    reg [6:0]  inf_gen_tokens [0:31];

    // Latency measurement
    reg [19:0] inf_latency_cnt;
    reg [19:0] inf_latency;

    always @(posedge clk) begin
        if (rst) begin
            inf_state      <= INF_IDLE;
            emb_start      <= 1'b0;
            b1_start       <= 1'b0;
            b2_start       <= 1'b0;
            b3_start       <= 1'b0;
            b4_start       <= 1'b0;
            lm_start       <= 1'b0;
            inf_gen_count  <= 8'd0;
            inf_got_argmax <= 1'b0;
            inf_latency_cnt <= 20'd0;
            tx_send        <= 1'b0;
        end else begin
            emb_start <= 1'b0;
            b1_start  <= 1'b0;
            b2_start  <= 1'b0;
            b3_start  <= 1'b0;
            b4_start  <= 1'b0;
            lm_start  <= 1'b0;
            tx_send   <= 1'b0;

            // Count inference clocks
            if (inf_state != INF_IDLE && inf_state != INF_SEND_RESP && inf_state != INF_SEND_STATUS)
                inf_latency_cnt <= inf_latency_cnt + 20'd1;

            if (argmax_valid) begin
                inf_got_argmax   <= 1'b1;
                inf_result_token <= predicted_token;
            end

            case (inf_state)
                INF_IDLE: begin
                    if (start_single_infer) begin
                        emb_token_id    <= cmd_token_id;
                        inf_is_seq      <= 1'b0;
                        inf_n_tokens    <= 8'd1;
                        inf_gen_count   <= 8'd0;
                        inf_latency_cnt <= 20'd0;
                        inf_state       <= INF_START_EMB;
                    end else if (start_seq_infer) begin
                        emb_token_id    <= cmd_token_id;
                        inf_is_seq      <= 1'b1;
                        inf_n_tokens    <= (cmd_n_tokens > MAX_GEN[7:0]) ? MAX_GEN[7:0] : cmd_n_tokens;
                        inf_gen_count   <= 8'd0;
                        inf_latency_cnt <= 20'd0;
                        inf_state       <= INF_START_EMB;
                    end else if (start_status) begin
                        inf_state <= INF_SEND_STATUS;
                    end
                end

                INF_START_EMB: begin emb_start <= 1'b1; inf_state <= INF_RUN_EMB; end
                INF_RUN_EMB:  begin if (emb_done) inf_state <= INF_START_B1; end

                INF_START_B1: begin b1_start <= 1'b1; inf_state <= INF_RUN_B1; end
                INF_RUN_B1:   begin if (b1_done) inf_state <= INF_START_B2; end

                INF_START_B2: begin b2_start <= 1'b1; inf_state <= INF_RUN_B2; end
                INF_RUN_B2:   begin if (b2_done) inf_state <= INF_START_B3; end

                INF_START_B3: begin b3_start <= 1'b1; inf_state <= INF_RUN_B3; end
                INF_RUN_B3:   begin if (b3_done) inf_state <= INF_START_B4; end

                INF_START_B4: begin b4_start <= 1'b1; inf_state <= INF_RUN_B4; end
                INF_RUN_B4:   begin if (b4_done) inf_state <= INF_START_LM; end

                INF_START_LM: begin
                    lm_start       <= 1'b1;
                    inf_got_argmax <= 1'b0;
                    inf_state      <= INF_RUN_LM;
                end

                INF_RUN_LM: begin
                    if (lm_done) inf_state <= INF_WAIT_ARG;
                end

                INF_WAIT_ARG: begin
                    if (inf_got_argmax) begin
                        inf_gen_tokens[inf_gen_count[4:0]] <= inf_result_token;
                        inf_gen_count <= inf_gen_count + 8'd1;
                        inf_latency   <= inf_latency_cnt;
                        inf_state     <= INF_GOT_TOKEN;
                    end
                end

                INF_GOT_TOKEN: begin
                    if (inf_is_seq && inf_gen_count < inf_n_tokens) begin
                        emb_token_id    <= inf_result_token;
                        inf_latency_cnt <= 20'd0;
                        inf_state       <= INF_START_EMB;
                    end else begin
                        inf_state <= INF_SEND_RESP;
                    end
                end

                INF_SEND_RESP: begin
                    // Handled by response sender below
                end

                INF_SEND_STATUS: begin
                    // Handled by response sender below
                end

                default: inf_state <= INF_IDLE;
            endcase
        end
    end

    // =====================================================================
    // RESPONSE SENDER
    // =====================================================================
    reg       resp_sending;
    reg [5:0] resp_idx;
    reg [5:0] resp_len;

    always @(posedge clk) begin
        if (rst) begin
            resp_sending <= 1'b0;
            resp_idx     <= 6'd0;
        end else begin
            if (inf_state == INF_SEND_RESP && !resp_sending) begin
                resp_sending <= 1'b1;
                resp_idx     <= 6'd0;
                if (inf_is_seq)
                    resp_len <= 6'd3 + {1'b0, inf_gen_count[4:0]};  // SYNC + RESP + N + tokens
                else
                    resp_len <= 6'd6;  // SYNC + RESP + token + latency(3)
            end else if (inf_state == INF_SEND_STATUS && !resp_sending) begin
                resp_sending <= 1'b1;
                resp_idx     <= 6'd0;
                resp_len     <= 6'd5;
            end else if (resp_sending && tx_ready && !tx_send) begin
                if (inf_state == INF_SEND_STATUS) begin
                    case (resp_idx)
                        6'd0: tx_byte <= SYNC_BYTE;
                        6'd1: tx_byte <= RESP_STATUS;
                        6'd2: tx_byte <= {3'b0, inf_state};
                        6'd3: tx_byte <= inf_gen_count;
                        6'd4: tx_byte <= 8'h01;  // pass
                        default: ;
                    endcase
                end else if (!inf_is_seq) begin
                    // Single token response
                    case (resp_idx)
                        6'd0: tx_byte <= SYNC_BYTE;
                        6'd1: tx_byte <= RESP_INFER;
                        6'd2: tx_byte <= {1'b0, inf_result_token};
                        6'd3: tx_byte <= inf_latency[19:12];
                        6'd4: tx_byte <= inf_latency[11:4];
                        6'd5: tx_byte <= {inf_latency[3:0], 4'b0};
                        default: ;
                    endcase
                end else begin
                    // Sequence response
                    case (resp_idx)
                        6'd0: tx_byte <= SYNC_BYTE;
                        6'd1: tx_byte <= RESP_SEQ;
                        6'd2: tx_byte <= inf_gen_count;
                        default: begin
                            if (resp_idx >= 6'd3 && resp_idx < resp_len)
                                tx_byte <= {1'b0, inf_gen_tokens[resp_idx - 6'd3]};
                        end
                    endcase
                end

                tx_send <= 1'b1;
                if (resp_idx == resp_len - 6'd1) begin
                    resp_sending <= 1'b0;
                    inf_state    <= INF_IDLE;
                end else
                    resp_idx <= resp_idx + 6'd1;
            end
        end
    end

    // =====================================================================
    // LED — Blink during inference, solid when idle
    // =====================================================================
    reg [24:0] led_counter;
    reg        led_state;

    always @(posedge clk) begin
        if (rst) begin
            led_counter <= 25'd0;
            led_state   <= 1'b0;
        end else begin
            led_counter <= led_counter + 1;
            if (inf_state == INF_IDLE)
                led_state <= 1'b1;  // Solid ON when idle (ready)
            else if (led_counter == 25'd3_125_000) begin
                led_counter <= 25'd0;
                led_state <= ~led_state;  // Fast blink during inference
            end
        end
    end

    assign led = ~led_state;
    assign debug_state[0] = (inf_state != INF_IDLE);  // Busy
    assign debug_state[1] = resp_sending;              // Responding

endmodule
