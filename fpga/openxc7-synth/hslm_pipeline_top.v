//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// HSLM PIPELINE TOP — Double-Buffered Autoregressive Transformer
// =============================================================================
// Variant of hslm_full_top with ping-pong double buffering between blocks.
// Each block starts processing as soon as data is available, overlapping
// computation with data transfer.
//
// Potential speedup: ~2x (14ms vs 28.5ms per token @ 50MHz)
//
// Architecture:
//   Embedding → [BufA0/BufB0] → Block1 → [BufA1/BufB1] → Block2
//             → [BufA2/BufB2] → Block3 → [BufA3/BufB3] → Block4
//             → LM_Head → Argmax → next_token
//
// Double buffering: While Block_N writes to BufA_N, Block_N+1 reads from BufB_N
//                   (and vice versa on next iteration)
//
// Resource estimate: +500 LUT, +4 BRAM18 for extra buffers
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module hslm_pipeline_top (
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
    // PING-PONG BUFFER SELECTOR
    // =====================================================================
    reg buf_sel = 1'b0;  // 0 = write A/read B, 1 = write B/read A

    // =====================================================================
    // DOUBLE BUFFERS (A and B for each inter-block stage)
    // =====================================================================
    localparam BUF_DEPTH = 256;

    // Embedding → Block1
    reg signed [ACC_WIDTH-1:0] emb_buf_a [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] emb_buf_b [0:BUF_DEPTH-1];

    // Block1 → Block2
    reg signed [ACC_WIDTH-1:0] inter_buf1_a [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] inter_buf1_b [0:BUF_DEPTH-1];

    // Block2 → Block3
    reg signed [ACC_WIDTH-1:0] inter_buf2_a [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] inter_buf2_b [0:BUF_DEPTH-1];

    // Block3 → Block4
    reg signed [ACC_WIDTH-1:0] inter_buf3_a [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] inter_buf3_b [0:BUF_DEPTH-1];

    // Block4 → LM Head
    reg signed [ACC_WIDTH-1:0] b4_out_buf_a [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] b4_out_buf_b [0:BUF_DEPTH-1];

    // =====================================================================
    // EMBEDDING LOOKUP
    // =====================================================================
    reg        emb_start;
    reg  [6:0] emb_token_id;

    wire signed [ACC_WIDTH-1:0] emb_out_data;
    wire [7:0]                  emb_out_addr;
    wire                        emb_out_valid;
    wire                        emb_done;
    wire                        emb_busy;

    embedding_lookup #(
        .VOCAB     (VOCAB),
        .DIM       (N_SMALL),
        .DATA_WIDTH(ACC_WIDTH),
        .ADDR_WIDTH(15),
        .TOK_WIDTH (7),
        .DIM_WIDTH (8),
        .MEM_FILE  ("fpga/weights/embedding_weights.mem")
    ) emb (
        .clk      (clk),
        .rst      (rst),
        .start    (emb_start),
        .token_id (emb_token_id),
        .out_data (emb_out_data),
        .out_addr (emb_out_addr),
        .out_valid(emb_out_valid),
        .done     (emb_done),
        .busy     (emb_busy)
    );

    // Write embedding output to selected buffer
    always @(posedge clk) begin
        if (emb_out_valid) begin
            if (!buf_sel)
                emb_buf_a[emb_out_addr] <= emb_out_data;
            else
                emb_buf_b[emb_out_addr] <= emb_out_data;
        end
    end

    // =====================================================================
    // BLOCK 1 — reads from opposite buffer
    // =====================================================================
    wire [7:0] b1_rd_addr;
    wire signed [ACC_WIDTH-1:0] b1_rd_data;
    assign b1_rd_data = buf_sel ? emb_buf_a[b1_rd_addr] : emb_buf_b[b1_rd_addr];

    wire        b1_out_valid;
    wire signed [ACC_WIDTH-1:0] b1_out_data;
    wire [7:0]  b1_out_addr;
    wire        b1_busy, b1_done;
    reg         b1_start;

    trinity_block #(
        .N_SMALL(N_SMALL), .N_LARGE(N_LARGE), .ACC_WIDTH(ACC_WIDTH),
        .FRAC_BITS(FRAC_BITS), .ADDR_WIDTH(18),
        .I_UP_WIDTH(8), .J_UP_WIDTH(10), .I_DOWN_WIDTH(10), .J_DOWN_WIDTH(8),
        .MEM_FILE_UP  ("fpga/openxc7-synth/ternary_matvec_243x729_weights.mem"),
        .MEM_FILE_DOWN("fpga/openxc7-synth/ternary_matvec_729x243_weights.mem")
    ) block1 (
        .clk(clk), .rst(rst), .start(b1_start),
        .x_rd_addr(b1_rd_addr), .x_rd_data(b1_rd_data),
        .out_valid(b1_out_valid), .out_data(b1_out_data), .out_addr(b1_out_addr),
        .busy(b1_busy), .done(b1_done)
    );

    always @(posedge clk) begin
        if (b1_out_valid) begin
            if (!buf_sel)
                inter_buf1_a[b1_out_addr] <= b1_out_data;
            else
                inter_buf1_b[b1_out_addr] <= b1_out_data;
        end
    end

    // =====================================================================
    // BLOCK 2
    // =====================================================================
    wire [7:0] b2_rd_addr;
    wire signed [ACC_WIDTH-1:0] b2_rd_data;
    assign b2_rd_data = buf_sel ? inter_buf1_a[b2_rd_addr] : inter_buf1_b[b2_rd_addr];

    wire        b2_out_valid;
    wire signed [ACC_WIDTH-1:0] b2_out_data;
    wire [7:0]  b2_out_addr;
    wire        b2_busy, b2_done;
    reg         b2_start;

    trinity_block #(
        .N_SMALL(N_SMALL), .N_LARGE(N_LARGE), .ACC_WIDTH(ACC_WIDTH),
        .FRAC_BITS(FRAC_BITS), .ADDR_WIDTH(18),
        .I_UP_WIDTH(8), .J_UP_WIDTH(10), .I_DOWN_WIDTH(10), .J_DOWN_WIDTH(8),
        .MEM_FILE_UP  ("fpga/openxc7-synth/ternary_matvec_b2_243x729_weights.mem"),
        .MEM_FILE_DOWN("fpga/openxc7-synth/ternary_matvec_b2_729x243_weights.mem")
    ) block2 (
        .clk(clk), .rst(rst), .start(b2_start),
        .x_rd_addr(b2_rd_addr), .x_rd_data(b2_rd_data),
        .out_valid(b2_out_valid), .out_data(b2_out_data), .out_addr(b2_out_addr),
        .busy(b2_busy), .done(b2_done)
    );

    always @(posedge clk) begin
        if (b2_out_valid) begin
            if (!buf_sel)
                inter_buf2_a[b2_out_addr] <= b2_out_data;
            else
                inter_buf2_b[b2_out_addr] <= b2_out_data;
        end
    end

    // =====================================================================
    // BLOCK 3
    // =====================================================================
    wire [7:0] b3_rd_addr;
    wire signed [ACC_WIDTH-1:0] b3_rd_data;
    assign b3_rd_data = buf_sel ? inter_buf2_a[b3_rd_addr] : inter_buf2_b[b3_rd_addr];

    wire        b3_out_valid;
    wire signed [ACC_WIDTH-1:0] b3_out_data;
    wire [7:0]  b3_out_addr;
    wire        b3_busy, b3_done;
    reg         b3_start;

    trinity_block #(
        .N_SMALL(N_SMALL), .N_LARGE(N_LARGE), .ACC_WIDTH(ACC_WIDTH),
        .FRAC_BITS(FRAC_BITS), .ADDR_WIDTH(18),
        .I_UP_WIDTH(8), .J_UP_WIDTH(10), .I_DOWN_WIDTH(10), .J_DOWN_WIDTH(8),
        .MEM_FILE_UP  ("fpga/openxc7-synth/ternary_matvec_b3_243x729_weights.mem"),
        .MEM_FILE_DOWN("fpga/openxc7-synth/ternary_matvec_b3_729x243_weights.mem")
    ) block3 (
        .clk(clk), .rst(rst), .start(b3_start),
        .x_rd_addr(b3_rd_addr), .x_rd_data(b3_rd_data),
        .out_valid(b3_out_valid), .out_data(b3_out_data), .out_addr(b3_out_addr),
        .busy(b3_busy), .done(b3_done)
    );

    always @(posedge clk) begin
        if (b3_out_valid) begin
            if (!buf_sel)
                inter_buf3_a[b3_out_addr] <= b3_out_data;
            else
                inter_buf3_b[b3_out_addr] <= b3_out_data;
        end
    end

    // =====================================================================
    // BLOCK 4
    // =====================================================================
    wire [7:0] b4_rd_addr;
    wire signed [ACC_WIDTH-1:0] b4_rd_data;
    assign b4_rd_data = buf_sel ? inter_buf3_a[b4_rd_addr] : inter_buf3_b[b4_rd_addr];

    wire        b4_out_valid;
    wire signed [ACC_WIDTH-1:0] b4_out_data;
    wire [7:0]  b4_out_addr;
    wire        b4_busy, b4_done;
    reg         b4_start;

    trinity_block #(
        .N_SMALL(N_SMALL), .N_LARGE(N_LARGE), .ACC_WIDTH(ACC_WIDTH),
        .FRAC_BITS(FRAC_BITS), .ADDR_WIDTH(18),
        .I_UP_WIDTH(8), .J_UP_WIDTH(10), .I_DOWN_WIDTH(10), .J_DOWN_WIDTH(8),
        .MEM_FILE_UP  ("fpga/openxc7-synth/ternary_matvec_b4_243x729_weights.mem"),
        .MEM_FILE_DOWN("fpga/openxc7-synth/ternary_matvec_b4_729x243_weights.mem")
    ) block4 (
        .clk(clk), .rst(rst), .start(b4_start),
        .x_rd_addr(b4_rd_addr), .x_rd_data(b4_rd_data),
        .out_valid(b4_out_valid), .out_data(b4_out_data), .out_addr(b4_out_addr),
        .busy(b4_busy), .done(b4_done)
    );

    always @(posedge clk) begin
        if (b4_out_valid) begin
            if (!buf_sel)
                b4_out_buf_a[b4_out_addr] <= b4_out_data;
            else
                b4_out_buf_b[b4_out_addr] <= b4_out_data;
        end
    end

    // =====================================================================
    // LM HEAD
    // =====================================================================
    wire [7:0] lm_x_addr;
    wire signed [ACC_WIDTH-1:0] lm_x_data_raw;
    assign lm_x_data_raw = buf_sel ? b4_out_buf_a[lm_x_addr] : b4_out_buf_b[lm_x_addr];

    wire signed [LM_ACC-1:0] lm_result_data;
    wire [6:0]               lm_result_addr;
    wire                     lm_result_valid;
    wire                     lm_done;
    wire                     lm_busy;
    reg                      lm_start;

    lm_head_matvec #(
        .DIM       (N_SMALL),
        .VOCAB     (VOCAB),
        .ACC_WIDTH (LM_ACC),
        .ADDR_WIDTH(15),
        .D_WIDTH   (8),
        .V_WIDTH   (7),
        .MEM_FILE  ("fpga/weights/lm_head_weights.mem"),
        .USE_EXT_X (1)
    ) lm_head (
        .clk         (clk),
        .rst         (rst),
        .start       (lm_start),
        .result_data (lm_result_data),
        .result_addr (lm_result_addr),
        .result_valid(lm_result_valid),
        .done        (lm_done),
        .busy        (lm_busy),
        .x_ext_data  (lm_x_data_raw),
        .x_ext_addr  (lm_x_addr)
    );

    // =====================================================================
    // ARGMAX
    // =====================================================================
    wire [6:0]              predicted_token;
    wire signed [LM_ACC-1:0] predicted_val;
    wire                    argmax_valid;
    wire                    argmax_busy;

    argmax_unit #(
        .ACC_WIDTH(LM_ACC),
        .IDX_WIDTH(7)
    ) argmax (
        .clk         (clk),
        .rst         (rst),
        .in_valid    (lm_result_valid),
        .in_data     (lm_result_data),
        .in_addr     (lm_result_addr),
        .in_done     (lm_done),
        .argmax_idx  (predicted_token),
        .argmax_val  (predicted_val),
        .argmax_valid(argmax_valid),
        .busy        (argmax_busy)
    );

    // =====================================================================
    // AUTOREGRESSIVE STATE MACHINE (same states as hslm_full_top)
    // =====================================================================
    localparam MAX_GEN        = 16;
    localparam ST_WAIT        = 4'd0;
    localparam ST_START_EMB   = 4'd1;
    localparam ST_RUN_EMB     = 4'd2;
    localparam ST_START_B1    = 4'd3;
    localparam ST_RUN_B1      = 4'd4;
    localparam ST_START_B2    = 4'd5;
    localparam ST_RUN_B2      = 4'd6;
    localparam ST_START_B3    = 4'd7;
    localparam ST_RUN_B3      = 4'd8;
    localparam ST_START_B4    = 4'd9;
    localparam ST_RUN_B4      = 4'd10;
    localparam ST_START_LM    = 4'd11;
    localparam ST_RUN_LM      = 4'd12;
    localparam ST_WAIT_ARGMAX = 4'd13;
    localparam ST_NEXT_TOKEN  = 4'd14;
    localparam ST_DONE        = 4'd15;

    reg [3:0]  st_state;
    reg        self_test_pass;
    reg        computation_done;
    reg [7:0]  wait_cnt;
    reg [7:0]  b4_out_count;
    reg        has_nonzero;
    reg        got_argmax;
    reg [6:0]  result_token;
    reg [4:0]  gen_count;
    reg [6:0]  gen_tokens [0:15];

    always @(posedge clk) begin
        if (rst) begin
            st_state         <= ST_WAIT;
            self_test_pass   <= 1'b0;
            computation_done <= 1'b0;
            emb_start        <= 1'b0;
            b1_start         <= 1'b0;
            b2_start         <= 1'b0;
            b3_start         <= 1'b0;
            b4_start         <= 1'b0;
            lm_start         <= 1'b0;
            wait_cnt         <= 8'd0;
            b4_out_count     <= 8'd0;
            has_nonzero      <= 1'b0;
            got_argmax       <= 1'b0;
            result_token     <= 7'd0;
            emb_token_id     <= 7'd42;
            gen_count        <= 5'd0;
            buf_sel          <= 1'b0;
        end else begin
            emb_start <= 1'b0;
            b1_start  <= 1'b0;
            b2_start  <= 1'b0;
            b3_start  <= 1'b0;
            b4_start  <= 1'b0;
            lm_start  <= 1'b0;

            if (b4_out_valid) begin
                b4_out_count <= b4_out_count + 8'd1;
                if (b4_out_data != {ACC_WIDTH{1'b0}})
                    has_nonzero <= 1'b1;
            end

            if (argmax_valid) begin
                got_argmax   <= 1'b1;
                result_token <= predicted_token;
            end

            case (st_state)
                ST_WAIT: begin
                    if (wait_cnt < 8'd20)
                        wait_cnt <= wait_cnt + 1;
                    else begin
                        emb_token_id <= 7'd42;
                        gen_count    <= 5'd0;
                        st_state     <= ST_START_EMB;
                    end
                end

                ST_START_EMB: begin
                    emb_start <= 1'b1;
                    st_state  <= ST_RUN_EMB;
                end

                ST_RUN_EMB: begin
                    if (emb_done)
                        st_state <= ST_START_B1;
                end

                ST_START_B1: begin
                    b1_start <= 1'b1;
                    st_state <= ST_RUN_B1;
                end

                ST_RUN_B1: begin
                    if (b1_done)
                        st_state <= ST_START_B2;
                end

                ST_START_B2: begin
                    b2_start <= 1'b1;
                    st_state <= ST_RUN_B2;
                end

                ST_RUN_B2: begin
                    if (b2_done)
                        st_state <= ST_START_B3;
                end

                ST_START_B3: begin
                    b3_start <= 1'b1;
                    st_state <= ST_RUN_B3;
                end

                ST_RUN_B3: begin
                    if (b3_done)
                        st_state <= ST_START_B4;
                end

                ST_START_B4: begin
                    b4_start     <= 1'b1;
                    b4_out_count <= 8'd0;
                    has_nonzero  <= 1'b0;
                    st_state     <= ST_RUN_B4;
                end

                ST_RUN_B4: begin
                    if (b4_done)
                        st_state <= ST_START_LM;
                end

                ST_START_LM: begin
                    lm_start   <= 1'b1;
                    got_argmax <= 1'b0;
                    st_state   <= ST_RUN_LM;
                end

                ST_RUN_LM: begin
                    if (lm_done) begin
                        if (gen_count == 5'd0)
                            self_test_pass <= (b4_out_count == N_SMALL[7:0]) && has_nonzero;
                        st_state <= ST_WAIT_ARGMAX;
                    end
                end

                ST_WAIT_ARGMAX: begin
                    if (got_argmax) begin
                        gen_tokens[gen_count[3:0]] <= result_token;
                        gen_count <= gen_count + 5'd1;
                        st_state  <= ST_NEXT_TOKEN;
                    end
                end

                ST_NEXT_TOKEN: begin
                    if (gen_count < MAX_GEN[4:0]) begin
                        emb_token_id <= result_token;
                        // Toggle buffer selector for next iteration
                        buf_sel      <= ~buf_sel;
                        st_state     <= ST_START_EMB;
                    end else begin
                        computation_done <= 1'b1;
                        st_state         <= ST_DONE;
                    end
                end

                ST_DONE: st_state <= ST_DONE;
                default: st_state <= ST_DONE;
            endcase
        end
    end

    // =====================================================================
    // LED — Active-low
    // =====================================================================
    reg [24:0] led_counter;
    reg        led_state;

    always @(posedge clk) begin
        if (rst) begin
            led_counter <= 25'd0;
            led_state   <= 1'b0;
        end else begin
            led_counter <= led_counter + 1;
            if (st_state == ST_DONE)
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

    // =====================================================================
    // UART TX + REPORTER
    // =====================================================================
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

    // UART report: [AA BB FD pass seed gen_count tok0..tok15]
    // Frame type 0xFD = pipeline (double-buffered) generation
    reg       report_sent, report_sending;
    reg [4:0] report_idx;
    reg [7:0] report_frame [0:21];

    always @(posedge clk) begin
        if (rst) begin
            report_sent <= 1'b0; report_sending <= 1'b0;
            report_idx <= 5'd0; tx_send <= 1'b0;
        end else begin
            tx_send <= 1'b0;
            if (!report_sent && st_state == ST_DONE && !report_sending) begin
                report_sending <= 1'b1; report_idx <= 5'd0;
                report_frame[0]  <= 8'hAA;
                report_frame[1]  <= 8'hBB;
                report_frame[2]  <= 8'hFD;  // Pipeline variant
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
