// =============================================================================
// HSLM FULL TOP — Autoregressive Ternary Transformer on FPGA
// =============================================================================
// Autoregressive generation loop:
//   token_id → Embedding → Block₁ → Block₂ → Block₃ → Block₄
//            → LM_Head → Argmax → next_token_id → (loop back)
//
// Generates MAX_GEN tokens starting from seed token_id=42.
// Each generated token feeds back as input to the next iteration.
//
// Pipeline per token (~1.46M clocks @ 50 MHz = ~29.2 ms):
//   1. Embedding lookup (BRAM): token_id → 243-dim vector (~245 clk)
//   2. Four TrinityBlocks (sequential): 243→729→243 each (~1,440K clk)
//   3. LM Head (ternary MatVec): 243→128 logits (~31K clk)
//   4. Argmax: 128 logits → predicted token_id (~1 clk)
//
// UART report: sends generated token sequence after completion.
// LED D6: solid ON during generation, blinks when done (pass).
//
// Resources: ~98% BRAM, ~6% LUT, 0 DSP48, 92 MHz Fmax
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module hslm_full_top (
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
    localparam LM_ACC     = 32;    // wider accumulator for logits

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

    // =====================================================================
    // BUFFERS
    // =====================================================================
    localparam BUF_DEPTH = 256;

    // Embedding output → Block1 input
    reg signed [ACC_WIDTH-1:0] emb_buffer [0:BUF_DEPTH-1];

    // Inter-block buffers
    reg signed [ACC_WIDTH-1:0] inter_buf1 [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] inter_buf2 [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] inter_buf3 [0:BUF_DEPTH-1];

    // Block4 output → LM Head input
    reg signed [ACC_WIDTH-1:0] b4_output_buf [0:BUF_DEPTH-1];

    // Capture embedding output into buffer
    always @(posedge clk) begin
        if (emb_out_valid)
            emb_buffer[emb_out_addr] <= emb_out_data;
    end

    // =====================================================================
    // BLOCK 1
    // =====================================================================
    wire [7:0] b1_rd_addr;
    wire signed [ACC_WIDTH-1:0] b1_rd_data;
    assign b1_rd_data = emb_buffer[b1_rd_addr];

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
        if (b1_out_valid)
            inter_buf1[b1_out_addr] <= b1_out_data;
    end

    // =====================================================================
    // BLOCK 2
    // =====================================================================
    wire [7:0] b2_rd_addr;
    wire signed [ACC_WIDTH-1:0] b2_rd_data;
    assign b2_rd_data = inter_buf1[b2_rd_addr];

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
        if (b2_out_valid)
            inter_buf2[b2_out_addr] <= b2_out_data;
    end

    // =====================================================================
    // BLOCK 3
    // =====================================================================
    wire [7:0] b3_rd_addr;
    wire signed [ACC_WIDTH-1:0] b3_rd_data;
    assign b3_rd_data = inter_buf2[b3_rd_addr];

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
        if (b3_out_valid)
            inter_buf3[b3_out_addr] <= b3_out_data;
    end

    // =====================================================================
    // BLOCK 4
    // =====================================================================
    wire [7:0] b4_rd_addr;
    wire signed [ACC_WIDTH-1:0] b4_rd_data;
    assign b4_rd_data = inter_buf3[b4_rd_addr];

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

    // Capture Block4 output into buffer for LM Head
    always @(posedge clk) begin
        if (b4_out_valid)
            b4_output_buf[b4_out_addr] <= b4_out_data;
    end

    // =====================================================================
    // LM HEAD — 243 → 256 logits
    // =====================================================================
    wire [7:0] lm_x_addr;
    wire signed [ACC_WIDTH-1:0] lm_x_data_raw;
    assign lm_x_data_raw = b4_output_buf[lm_x_addr];

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
    // ARGMAX — 256 logits → predicted token
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
    // UART RESULT BUFFER
    // =====================================================================
    reg [ACC_WIDTH-1:0] uart_results [0:7];

    always @(posedge clk) begin
        if (b4_out_valid && b4_out_addr < 8'd8)
            uart_results[b4_out_addr[2:0]] <= b4_out_data;
    end

    // =====================================================================
    // AUTOREGRESSIVE STATE MACHINE
    // =====================================================================
    // Generates MAX_GEN tokens: seed(42) → token₁ → token₂ → ... → tokenₙ
    localparam MAX_GEN        = 16;  // generate 16 tokens
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

    // Autoregressive generation tracking
    reg [4:0]  gen_count;             // tokens generated so far [0..MAX_GEN]
    reg [6:0]  gen_tokens [0:15];     // generated token sequence (for UART report)

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
            emb_token_id     <= 7'd42;  // seed token
            gen_count        <= 5'd0;
        end else begin
            emb_start <= 1'b0;
            b1_start  <= 1'b0;
            b2_start  <= 1'b0;
            b3_start  <= 1'b0;
            b4_start  <= 1'b0;
            lm_start  <= 1'b0;

            // Track Block4 outputs
            if (b4_out_valid) begin
                b4_out_count <= b4_out_count + 8'd1;
                if (b4_out_data != {ACC_WIDTH{1'b0}})
                    has_nonzero <= 1'b1;
            end

            // Track argmax result
            if (argmax_valid) begin
                got_argmax   <= 1'b1;
                result_token <= predicted_token;
            end

            case (st_state)
                ST_WAIT: begin
                    if (wait_cnt < 8'd20)
                        wait_cnt <= wait_cnt + 1;
                    else begin
                        emb_token_id <= 7'd42;  // seed token
                        gen_count    <= 5'd0;
                        st_state     <= ST_START_EMB;
                    end
                end

                // --- EMBEDDING ---
                ST_START_EMB: begin
                    emb_start <= 1'b1;
                    st_state  <= ST_RUN_EMB;
                end

                ST_RUN_EMB: begin
                    if (emb_done)
                        st_state <= ST_START_B1;
                end

                // --- BLOCK 1 ---
                ST_START_B1: begin
                    b1_start <= 1'b1;
                    st_state <= ST_RUN_B1;
                end

                ST_RUN_B1: begin
                    if (b1_done)
                        st_state <= ST_START_B2;
                end

                // --- BLOCK 2 ---
                ST_START_B2: begin
                    b2_start <= 1'b1;
                    st_state <= ST_RUN_B2;
                end

                ST_RUN_B2: begin
                    if (b2_done)
                        st_state <= ST_START_B3;
                end

                // --- BLOCK 3 ---
                ST_START_B3: begin
                    b3_start <= 1'b1;
                    st_state <= ST_RUN_B3;
                end

                ST_RUN_B3: begin
                    if (b3_done)
                        st_state <= ST_START_B4;
                end

                // --- BLOCK 4 ---
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

                // --- LM HEAD ---
                ST_START_LM: begin
                    lm_start   <= 1'b1;
                    got_argmax <= 1'b0;
                    st_state   <= ST_RUN_LM;
                end

                ST_RUN_LM: begin
                    if (lm_done) begin
                        // First token validates pipeline
                        if (gen_count == 5'd0)
                            self_test_pass <= (b4_out_count == N_SMALL[7:0]) && has_nonzero;
                        st_state <= ST_WAIT_ARGMAX;
                    end
                end

                // --- WAIT FOR ARGMAX (1-2 clocks after lm_done) ---
                ST_WAIT_ARGMAX: begin
                    if (got_argmax) begin
                        // Store generated token
                        gen_tokens[gen_count[3:0]] <= result_token;
                        gen_count <= gen_count + 5'd1;
                        st_state  <= ST_NEXT_TOKEN;
                    end
                end

                // --- AUTOREGRESSIVE LOOP ---
                ST_NEXT_TOKEN: begin
                    if (gen_count < MAX_GEN[4:0]) begin
                        // Feed argmax output back as next input
                        emb_token_id <= result_token;
                        st_state     <= ST_START_EMB;
                    end else begin
                        // All tokens generated
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
    // UART TX + REPORTER (frame type 0xAA for full pipeline)
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

    // UART report frame: [AA BB FE pass seed gen_count tok0..tok15]
    // Frame type 0xFE = autoregressive generation
    // Total: 3 + 1 + 1 + 1 + 16 = 22 bytes
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
                report_frame[0]  <= 8'hAA;             // sync
                report_frame[1]  <= 8'hBB;             // sync
                report_frame[2]  <= 8'hFE;             // 0xFE = autoregressive
                report_frame[3]  <= {7'b0, self_test_pass};
                report_frame[4]  <= 8'd42;             // seed token
                report_frame[5]  <= {3'b0, gen_count}; // tokens generated
                // Generated token sequence (16 tokens)
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
