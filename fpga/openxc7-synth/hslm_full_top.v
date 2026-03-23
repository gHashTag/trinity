//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// HSLM FULL TOP — Autoregressive Ternary Transformer on FPGA
// =============================================================================
// Autoregressive generation loop (2-block variant for XC7A100T SLICEM fit):
//   token_id → Embedding → Block₁ → Block₂
//            → LM_Head → Argmax → next_token_id → (loop back)
//
// Generates MAX_GEN tokens starting from seed token_id=42.
// Each generated token feeds back as input to the next iteration.
//
// Pipeline per token (3 blocks + LM Head, all TMU K=16, wide BRAM):
//   1. Embedding lookup (BRAM): token_id → 243-dim vector (~248 clk)
//   2. Three TrinityBlocks (sequential): 243→729→243 each, TMU K=16 (~26K each)
//   3. LM Head (TMU K=16): 243→128 logits (~2,800 clk)
//   4. Argmax: 128 logits → predicted token_id (~1 clk)
//   Total: ~81K cycles/token → ~1,003 tok/s @ 81.25 MHz (MMCM from 50 MHz)
//   K=32 variant: ~43K cyc/tok, 1,881 tok/s — needs XC7A200T (72K LUT > 63K limit)
//
// UART report: sends generated token sequence after completion.
// LED D6: solid ON during generation, blinks when done (pass).
//
// 3 blocks matches training config. 0 DSP48.
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
    // CLOCK GENERATION — 50 MHz → 65 MHz via MMCM
    // =====================================================================
`ifdef SIMULATION
    wire sys_clk = clk;           // bypass MMCM in simulation
    wire mmcm_locked = 1'b1;
`else
    wire clk_65, clk_fb, mmcm_locked;

    MMCME2_BASE #(
        .CLKFBOUT_MULT_F (13.0),    // VCO = 50 × 13 = 650 MHz
        .CLKIN1_PERIOD   (20.0),     // 50 MHz input
        .CLKOUT0_DIVIDE_F(8.0),     // 650 / 8 = 81.25 MHz
        .DIVCLK_DIVIDE   (1)
    ) mmcm_inst (
        .CLKIN1  (clk),
        .CLKOUT0 (clk_65),
        .CLKFBIN (clk_fb),
        .CLKFBOUT(clk_fb),
        .PWRDWN  (1'b0),
        .RST     (1'b0),
        .LOCKED  (mmcm_locked)
    );

    wire sys_clk = clk_65;
`endif

    // =====================================================================
    // POWER-ON RESET (waits for MMCM lock)
    // =====================================================================
    reg [7:0] por_counter = 8'd0;
    reg       rst = 1'b1;

    always @(posedge sys_clk) begin
        if (!mmcm_locked) begin
            por_counter <= 8'd0;
            rst <= 1'b1;
        end else if (por_counter < 8'd255) begin
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
        .MEM_FILE  ("embedding_weights.mem")
    ) emb (
        .clk      (sys_clk),
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
    // Force registers (not DRAM) — nextpnr-xilinx DRAM packer has assertion bug
    (* ram_style = "registers" *)
    reg signed [ACC_WIDTH-1:0] emb_buffer [0:BUF_DEPTH-1];

    // Inter-block buffer
    (* ram_style = "registers" *)
    reg signed [ACC_WIDTH-1:0] inter_buf1 [0:BUF_DEPTH-1];

    // Block2 output → LM Head input (2-block variant: no Block3)
    (* ram_style = "registers" *)
    reg signed [ACC_WIDTH-1:0] b2_output_buf [0:BUF_DEPTH-1];

    // Capture embedding output into buffer
    always @(posedge sys_clk) begin
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
        .MEM_FILE_UP_PREFIX  ("tmu_w_b1_up"),
        .MEM_FILE_DOWN_PREFIX("tmu_w_b1_down")
    ) block1 (
        .clk(sys_clk), .rst(rst), .start(b1_start),
        .x_rd_addr(b1_rd_addr), .x_rd_data(b1_rd_data),
        .out_valid(b1_out_valid), .out_data(b1_out_data), .out_addr(b1_out_addr),
        .busy(b1_busy), .done(b1_done)
    );

    always @(posedge sys_clk) begin
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
        .MEM_FILE_UP_PREFIX  ("tmu_w_b2_up"),
        .MEM_FILE_DOWN_PREFIX("tmu_w_b2_down")
    ) block2 (
        .clk(sys_clk), .rst(rst), .start(b2_start),
        .x_rd_addr(b2_rd_addr), .x_rd_data(b2_rd_data),
        .out_valid(b2_out_valid), .out_data(b2_out_data), .out_addr(b2_out_addr),
        .busy(b2_busy), .done(b2_done)
    );

    // Capture Block2 output into buffer for LM Head (2-block variant)
    always @(posedge sys_clk) begin
        if (b2_out_valid)
            b2_output_buf[b2_out_addr] <= b2_out_data;
    end

    // =====================================================================
    // LM HEAD — 243 → 128 logits (TMU K=32)
    // =====================================================================
    wire [7:0] lm_x_addr;
    wire signed [ACC_WIDTH-1:0] lm_x_data_raw;
    assign lm_x_data_raw = b2_output_buf[lm_x_addr];

    // Sign-extend 20-bit input to 32-bit for wider logit accumulation
    wire signed [LM_ACC-1:0] lm_x_data_ext;
    assign lm_x_data_ext = {{(LM_ACC-ACC_WIDTH){lm_x_data_raw[ACC_WIDTH-1]}}, lm_x_data_raw};

    wire signed [LM_ACC-1:0] lm_result_data;
    wire [6:0]               lm_result_addr;
    wire                     lm_result_valid;
    wire                     lm_done;
    wire                     lm_busy;
    reg                      lm_start;

    tmu_top #(
        .N_IN           (N_SMALL),
        .N_OUT          (VOCAB),
        .K              (16),
        .ACC_WIDTH      (LM_ACC),
        .ADDR_WIDTH     (12),
        .I_WIDTH        (8),
        .J_WIDTH        (7),
        .MEM_FILE_PREFIX("lm_head"),
        .USE_EXT_X      (1)
    ) lm_head (
        .clk         (sys_clk),
        .rst         (rst),
        .start       (lm_start),
        .result_data (lm_result_data),
        .result_addr (lm_result_addr),
        .result_valid(lm_result_valid),
        .done        (lm_done),
        .busy        (lm_busy),
        .x_ext_data  (lm_x_data_ext),
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
        .clk         (sys_clk),
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

    always @(posedge sys_clk) begin
        if (b2_out_valid && b2_out_addr < 8'd8)
            uart_results[b2_out_addr[2:0]] <= b2_out_data;
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
    // Block 3 removed — 2-block variant for XC7A100T SLICEM fit
    localparam ST_START_LM    = 4'd7;
    localparam ST_RUN_LM      = 4'd8;
    localparam ST_WAIT_ARGMAX = 4'd9;
    localparam ST_NEXT_TOKEN  = 4'd10;
    localparam ST_DONE        = 4'd11;

    reg [3:0]  st_state;
    reg        self_test_pass;
    reg        computation_done;
    reg [7:0]  wait_cnt;
    reg [7:0]  b3_out_count;
    reg        has_nonzero;
    reg        got_argmax;
    reg [6:0]  result_token;

    // Autoregressive generation tracking
    reg [4:0]  gen_count;             // tokens generated so far [0..MAX_GEN]
    reg [6:0]  gen_tokens [0:15];     // generated token sequence (for UART report)

    // JTAG bridge — configurable parameters
    // Initial values map to FPGA INIT attributes — driven ONLY from bscan_tck domain
    reg [6:0]  seed_reg = 7'd42;      // JTAG-writable seed token (default 42)
    reg [4:0]  max_gen_reg = 5'd16;   // JTAG-writable max gen count (default 16)
    reg [31:0] cycle_count;           // sys_clk cycles during inference

    // JTAG start CDC (bscan_tck → sys_clk toggle synchronizer)
    // Initial value via INIT attribute — driven ONLY from bscan_tck UPDATE handler
    reg        jtag_start_toggle = 1'b0;
    reg [2:0]  jtag_start_sync;
    wire       jtag_start_pulse = jtag_start_sync[2] ^ jtag_start_sync[1];

    always @(posedge sys_clk) begin
        if (rst)
            jtag_start_sync <= 3'b0;
        else
            jtag_start_sync <= {jtag_start_sync[1:0], jtag_start_toggle};
    end

    always @(posedge sys_clk) begin
        if (rst) begin
            st_state         <= ST_WAIT;
            self_test_pass   <= 1'b0;
            computation_done <= 1'b0;
            emb_start        <= 1'b0;
            b1_start         <= 1'b0;
            b2_start         <= 1'b0;
            lm_start         <= 1'b0;
            wait_cnt         <= 8'd0;
            b3_out_count     <= 8'd0;
            has_nonzero      <= 1'b0;
            got_argmax       <= 1'b0;
            result_token     <= 7'd0;
            emb_token_id     <= 7'd42;  // seed token
            gen_count        <= 5'd0;
            cycle_count      <= 32'd0;
        end else begin
            emb_start <= 1'b0;
            b1_start  <= 1'b0;
            b2_start  <= 1'b0;
            lm_start  <= 1'b0;

            // Cycle counter — runs during inference, frozen in WAIT/DONE
            if (st_state != ST_WAIT && st_state != ST_DONE)
                cycle_count <= cycle_count + 32'd1;

            // Track Block2 outputs (2-block variant)
            if (b2_out_valid) begin
                b3_out_count <= b3_out_count + 8'd1;
                if (b2_out_data != {ACC_WIDTH{1'b0}})
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
                        emb_token_id <= seed_reg;
                        gen_count    <= 5'd0;
                        cycle_count  <= 32'd0;
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
                        st_state <= ST_START_LM;
                end

                // --- LM HEAD ---
                ST_START_LM: begin
                    lm_start     <= 1'b1;
                    got_argmax   <= 1'b0;
                    b3_out_count <= 8'd0;
                    has_nonzero  <= 1'b0;
                    st_state     <= ST_RUN_LM;
                end

                ST_RUN_LM: begin
                    if (lm_done) begin
                        // First token validates pipeline
                        if (gen_count == 5'd0)
                            self_test_pass <= (b3_out_count == N_SMALL[7:0]) && has_nonzero;
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
                    if (gen_count < max_gen_reg) begin
                        // Feed argmax output back as next input
                        emb_token_id <= result_token;
                        st_state     <= ST_START_EMB;
                    end else begin
                        // All tokens generated
                        computation_done <= 1'b1;
                        st_state         <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    if (jtag_start_pulse) begin
                        emb_token_id     <= seed_reg;
                        gen_count        <= 5'd0;
                        computation_done <= 1'b0;
                        self_test_pass   <= 1'b0;
                        cycle_count      <= 32'd0;
                        b3_out_count     <= 8'd0;
                        has_nonzero      <= 1'b0;
                        got_argmax       <= 1'b0;
                        st_state         <= ST_START_EMB;
                    end
                end
                default: st_state <= ST_DONE;
            endcase
        end
    end

    // =====================================================================
    // LED — Active-low
    // =====================================================================
    reg [24:0] led_counter;
    reg        led_state;

    always @(posedge sys_clk) begin
        if (rst) begin
            led_counter <= 25'd0;
            led_state   <= 1'b0;
        end else begin
            led_counter <= led_counter + 1;
            if (st_state == ST_DONE)
                led_state <= self_test_pass;
            else if (led_counter == 25'd10_156_250) begin  // 81.25 MHz × 0.125s
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
    localparam CLK_DIV = 44;  // 81.25 MHz / (16 × 115200) ≈ 44
    reg [15:0] baud_counter;
    reg [3:0]  tx_bit_idx;
    reg [7:0]  tx_shift;
    reg        tx_active;
    reg        uart_tx_reg;
    assign uart_tx = uart_tx_reg;

    reg       tx_send;
    reg [7:0] tx_byte;
    wire      tx_ready = !tx_active;

    always @(posedge sys_clk) begin
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

    always @(posedge sys_clk) begin
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

    // =====================================================================
    // JTAG BRIDGE — BSCANE2 host communication via JTAG cable
    // =====================================================================
    // No UART needed! Data flows through the existing DLC-10 JTAG cable.
    //
    // Protocol: 32-bit DR scan via USER1 instruction
    //   Host shifts in:  [CMD:8][ADDR:8][DATA:16]
    //   Host shifts out: [STATUS:8][RESPONSE:24]
    //
    // Commands:
    //   0x01 READ_REG(addr)      — read bridge register
    //   0x02 WRITE_REG(addr,d)   — write bridge register
    //   0x03 START_INFERENCE      — trigger new generation
    //
    // Read registers:
    //   0x00: STATUS  {done, pass, 1'b0, gen_count[4:0], st_state[3:0]}
    //   0x01: CYCLE_COUNT (full 32-bit)
    //   0x02: CONFIG  {3'b0, max_gen_reg[4:0], 1'b0, seed_reg[6:0]}
    //   0x10..0x1F: gen_tokens[0..15]
    //
    // Write registers:
    //   0x00: SEED[6:0]
    //   0x01: MAX_GEN[4:0]
    //
    // Resources: ~50 LUT, 0 BRAM, 0 DSP
    // CDC: sys_clk signals are quasi-static when read (stable in ST_DONE)
    // =====================================================================

    wire bscan_capture, bscan_drck, bscan_reset_w, bscan_runtest;
    wire bscan_sel, bscan_shift, bscan_tck, bscan_tdi, bscan_tms, bscan_update;
    wire bscan_tdo;

    BSCANE2 #(
        .JTAG_CHAIN(1)  // USER1
    ) bscan_inst (
        .CAPTURE (bscan_capture),
        .DRCK    (bscan_drck),
        .RESET   (bscan_reset_w),
        .RUNTEST (bscan_runtest),
        .SEL     (bscan_sel),
        .SHIFT   (bscan_shift),
        .TCK     (bscan_tck),
        .TDI     (bscan_tdi),
        .TMS     (bscan_tms),
        .UPDATE  (bscan_update),
        .TDO     (bscan_tdo)
    );

    // 32-bit shift register
    reg [31:0] bscan_sr;
    // Latched command fields from previous UPDATE
    reg [7:0]  bscan_cmd;
    reg [7:0]  bscan_addr;

    assign bscan_tdo = bscan_sr[0];

    // BSCANE2 shift register — operates in bscan_tck domain
    // On CAPTURE: load response based on previous command's address
    // On SHIFT: shift in new command, shift out response
    // On UPDATE: latch command and execute writes
    always @(posedge bscan_tck) begin
        if (bscan_sel) begin
            if (bscan_capture) begin
                // Load response for readback
                // Sys_clk signals are quasi-static here (stable for 1000s of TCK cycles)
                case (bscan_addr)
                    8'h00:   bscan_sr <= {16'b0, computation_done, self_test_pass,
                                          1'b0, gen_count, st_state};
                    8'h01:   bscan_sr <= cycle_count;
                    8'h02:   bscan_sr <= {16'b0, 3'b0, max_gen_reg, 1'b0, seed_reg};
                    default: begin
                        if (bscan_addr[7:4] == 4'h1)
                            bscan_sr <= {25'b0, gen_tokens[bscan_addr[3:0]]};
                        else
                            bscan_sr <= 32'hDEAD_BEEF;
                    end
                endcase
            end else if (bscan_shift) begin
                // Shift: TDI in at MSB, TDO out from LSB
                bscan_sr <= {bscan_tdi, bscan_sr[31:1]};
            end
        end
    end

    // Command latch and execution — on UPDATE
    always @(posedge bscan_tck) begin
        if (bscan_sel && bscan_update) begin
            bscan_cmd  <= bscan_sr[31:24];
            bscan_addr <= bscan_sr[23:16];

            // WRITE_REG (0x02): update configurable parameters
            if (bscan_sr[31:24] == 8'h02) begin
                case (bscan_sr[23:16])
                    8'h00: seed_reg    <= bscan_sr[6:0];
                    8'h01: max_gen_reg <= bscan_sr[4:0];
                    default: ;
                endcase
            end

            // START_INFERENCE (0x03) or WRITE_REG to CONTROL addr (0x02)
            if (bscan_sr[31:24] == 8'h03 ||
                (bscan_sr[31:24] == 8'h02 && bscan_sr[23:16] == 8'h02 && bscan_sr[0]))
                jtag_start_toggle <= ~jtag_start_toggle;
        end
    end

endmodule
