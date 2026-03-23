//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// TRINITY BLOCK STEP 4 — Full TrinityBlock: MatVec1 + ReLU + MatVec2 + Residual + RMSNorm
// =============================================================================
// Complete TrinityBlock forward pass on FPGA:
//   x[i]=i+1 → matvec1(243→729) → ReLU → buffer → matvec2(729→243)
//            → +x (residual) → RMSNorm → verify
//
// Self-test verification:
//   - 243 normalized outputs produced
//   - Signs preserved: sign(norm[k]) == sign(residual[k])
//   - Output count == 243
//   - LED solid ON = PASSED
//
// Resources: ~32 BRAM36, ~5K LUT, ~2.5K FF
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module trinity_block_step4_top (
    input  wire clk,
    input  wire uart_rx,
    output wire uart_tx,
    output wire led,
    output wire [1:0] debug_state
);

    // =====================================================================
    // PARAMETERS
    // =====================================================================
    localparam N1_IN      = 243;
    localparam N1_OUT     = 729;
    localparam N2_IN      = 729;
    localparam N2_OUT     = 243;
    localparam ACC_WIDTH  = 20;
    localparam FRAC_BITS  = 8;

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
    // INPUT BUFFER — store x[i]=i+1 for residual
    // =====================================================================
    localparam INPUT_BUF_DEPTH = 256;
    reg signed [ACC_WIDTH-1:0] input_buffer [0:INPUT_BUF_DEPTH-1];

    reg [7:0] fill_idx;
    reg       fill_done;

    // Residual read port
    reg  [7:0] res_rd_addr;
    wire signed [ACC_WIDTH-1:0] res_rd_data;
    assign res_rd_data = input_buffer[res_rd_addr];

    // =====================================================================
    // STAGE 1: MATVEC1 (243 → 729)
    // =====================================================================
    wire signed [ACC_WIDTH-1:0] mv1_data;
    wire [9:0]                  mv1_addr;
    wire                        mv1_valid;
    wire                        mv1_done;
    wire                        mv1_busy;
    reg                         mv1_start;

    ternary_matvec_bram #(
        .N_IN      (N1_IN),
        .N_OUT     (N1_OUT),
        .ACC_WIDTH (ACC_WIDTH),
        .ADDR_WIDTH(18),
        .I_WIDTH   (8),
        .J_WIDTH   (10),
        .MEM_FILE  ("fpga/openxc7-synth/ternary_matvec_243x729_weights.mem"),
        .USE_EXT_X (0)
    ) matvec1 (
        .clk         (clk),
        .rst         (rst),
        .start       (mv1_start),
        .result_data (mv1_data),
        .result_addr (mv1_addr),
        .result_valid(mv1_valid),
        .done        (mv1_done),
        .busy        (mv1_busy),
        .x_ext_data  ({ACC_WIDTH{1'b0}}),
        .x_ext_addr  ()
    );

    // =====================================================================
    // STAGE 2: ReLU ACTIVATION
    // =====================================================================
    wire                        relu_valid;
    wire signed [ACC_WIDTH-1:0] relu_data;
    wire                        relu_done;

    ternary_activation #(.WIDTH(ACC_WIDTH)) activation (
        .clk(clk), .rst(rst),
        .valid_in(mv1_valid), .data_in(mv1_data), .done_in(mv1_done),
        .valid_out(relu_valid), .data_out(relu_data), .done_out(relu_done)
    );

    reg [9:0] mv1_addr_d1;
    always @(posedge clk) begin
        mv1_addr_d1 <= mv1_addr;
    end

    // =====================================================================
    // INTERMEDIATE BUFFER — 729 x ACC_WIDTH
    // =====================================================================
    localparam BUF_DEPTH = 1024;
    reg signed [ACC_WIDTH-1:0] relu_buffer [0:BUF_DEPTH-1];

    always @(posedge clk) begin
        if (relu_valid)
            relu_buffer[mv1_addr_d1] <= relu_data;
    end

    wire [9:0] mv2_x_addr;
    wire signed [ACC_WIDTH-1:0] mv2_x_data;
    assign mv2_x_data = relu_buffer[mv2_x_addr];

    // =====================================================================
    // STAGE 3: MATVEC2 (729 → 243)
    // =====================================================================
    wire signed [ACC_WIDTH-1:0] mv2_data;
    wire [7:0]                  mv2_addr;
    wire                        mv2_valid;
    wire                        mv2_done;
    wire                        mv2_busy;
    reg                         mv2_start;

    ternary_matvec_bram #(
        .N_IN      (N2_IN),
        .N_OUT     (N2_OUT),
        .ACC_WIDTH (ACC_WIDTH),
        .ADDR_WIDTH(18),
        .I_WIDTH   (10),
        .J_WIDTH   (8),
        .MEM_FILE  ("fpga/openxc7-synth/ternary_matvec_729x243_weights.mem"),
        .USE_EXT_X (1)
    ) matvec2 (
        .clk         (clk),
        .rst         (rst),
        .start       (mv2_start),
        .result_data (mv2_data),
        .result_addr (mv2_addr),
        .result_valid(mv2_valid),
        .done        (mv2_done),
        .busy        (mv2_busy),
        .x_ext_data  (mv2_x_data),
        .x_ext_addr  (mv2_x_addr)
    );

    // =====================================================================
    // STAGE 4: RESIDUAL — inline with matvec2 output
    // =====================================================================
    wire signed [ACC_WIDTH-1:0] residual_data;
    assign residual_data = mv2_data + res_rd_data;

    always @(*) begin
        res_rd_addr = mv2_addr;
    end

    // =====================================================================
    // STAGE 5: RMS NORM
    // =====================================================================
    // Feed residual output into rmsnorm, capture normalized output.
    wire                        norm_valid;
    wire signed [ACC_WIDTH-1:0] norm_data;
    wire [7:0]                  norm_addr;
    wire                        norm_done;

    ternary_rmsnorm #(
        .WIDTH    (ACC_WIDTH),
        .N        (N2_OUT),
        .ADDR_W   (8),
        .FRAC_BITS(FRAC_BITS),
        .LOG2_N   (8)
    ) rmsnorm (
        .clk      (clk),
        .rst      (rst),
        .in_valid (mv2_valid),
        .in_data  (residual_data),
        .in_addr  (mv2_addr),
        .in_done  (mv2_done),
        .out_valid(norm_valid),
        .out_data (norm_data),
        .out_addr (norm_addr),
        .out_done (norm_done)
    );

    // =====================================================================
    // SIGN BUFFER — store residual signs for verification
    // =====================================================================
    reg [0:0] residual_sign [0:INPUT_BUF_DEPTH-1];

    always @(posedge clk) begin
        if (mv2_valid)
            residual_sign[mv2_addr] <= residual_data[ACC_WIDTH-1];
    end

    // =====================================================================
    // UART RESULT BUFFER — first 8 final results (after norm)
    // =====================================================================
    reg [ACC_WIDTH-1:0] uart_results [0:7];

    always @(posedge clk) begin
        if (norm_valid && norm_addr < 8'd8)
            uart_results[norm_addr[2:0]] <= norm_data;
    end

    // =====================================================================
    // SELF-TEST STATE MACHINE
    // =====================================================================
    localparam ST_WAIT       = 4'd0;
    localparam ST_FILL_INPUT = 4'd1;
    localparam ST_START1     = 4'd2;
    localparam ST_LAYER1     = 4'd3;
    localparam ST_START2     = 4'd4;
    localparam ST_LAYER2     = 4'd5;  // matvec2 + residual + rmsnorm feed
    localparam ST_VERIFY     = 4'd6;  // wait for rmsnorm output + verify
    localparam ST_DONE       = 4'd7;

    reg [3:0]          st_state;
    reg                self_test_pass;
    reg                computation_done;
    reg [7:0]          wait_cnt;
    reg                verify_fail;
    reg [7:0]          check_count;
    reg [1:0]          k_mod3;

    always @(posedge clk) begin
        if (rst) begin
            st_state         <= ST_WAIT;
            self_test_pass   <= 1'b0;
            computation_done <= 1'b0;
            mv1_start        <= 1'b0;
            mv2_start        <= 1'b0;
            wait_cnt         <= 8'd0;
            verify_fail      <= 1'b0;
            check_count      <= 8'd0;
            k_mod3           <= 2'd0;
            fill_idx         <= 8'd0;
            fill_done        <= 1'b0;
        end else begin
            mv1_start <= 1'b0;
            mv2_start <= 1'b0;

            case (st_state)
                ST_WAIT: begin
                    if (wait_cnt < 8'd20)
                        wait_cnt <= wait_cnt + 1;
                    else begin
                        fill_idx  <= 8'd0;
                        fill_done <= 1'b0;
                        st_state  <= ST_FILL_INPUT;
                    end
                end

                ST_FILL_INPUT: begin
                    input_buffer[fill_idx] <= {{(ACC_WIDTH-8-1){1'b0}}, fill_idx} + {{(ACC_WIDTH-1){1'b0}}, 1'b1};
                    if (fill_idx == N1_IN[7:0] - 8'd1) begin
                        fill_done <= 1'b1;
                        st_state  <= ST_START1;
                    end else
                        fill_idx <= fill_idx + 8'd1;
                end

                ST_START1: begin
                    mv1_start <= 1'b1;
                    st_state  <= ST_LAYER1;
                end

                ST_LAYER1: begin
                    if (relu_done)
                        st_state <= ST_START2;
                end

                ST_START2: begin
                    k_mod3      <= 2'd0;
                    verify_fail <= 1'b0;
                    check_count <= 8'd0;
                    mv2_start   <= 1'b1;
                    st_state    <= ST_LAYER2;
                end

                ST_LAYER2: begin
                    // matvec2 runs, residual computed inline, feeds rmsnorm
                    // residual signs stored for verification
                    if (mv2_done)
                        st_state <= ST_VERIFY;
                end

                ST_VERIFY: begin
                    // Verify normalized output from rmsnorm
                    if (norm_valid) begin
                        // Check sign preservation: sign(norm) should match sign(residual)
                        // For zero residual values, normalized can be zero (either sign OK)
                        if (residual_sign[norm_addr] != norm_data[ACC_WIDTH-1] &&
                            norm_data != {ACC_WIDTH{1'b0}})
                            verify_fail <= 1'b1;
                        check_count <= check_count + 8'd1;
                    end
                    if (norm_done) begin
                        computation_done <= 1'b1;
                        // norm_done fires same cycle as last norm_valid,
                        // so check_count is N-1 at this point (incremented same cycle)
                        self_test_pass <= ~verify_fail && (check_count + 8'd1 == N2_OUT[7:0]);
                        st_state <= ST_DONE;
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
    // UART TX + REPORTER (frame type 0x66 for step4 / full block)
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

    reg       report_sent, report_sending;
    reg [4:0] report_idx;
    reg [7:0] report_frame [0:19];

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
                report_frame[2]  <= 8'h66;  // step4 = full TrinityBlock
                report_frame[3]  <= {7'b0, self_test_pass};
                report_frame[4]  <= uart_results[0][15:8];
                report_frame[5]  <= uart_results[0][7:0];
                report_frame[6]  <= uart_results[1][15:8];
                report_frame[7]  <= uart_results[1][7:0];
                report_frame[8]  <= uart_results[2][15:8];
                report_frame[9]  <= uart_results[2][7:0];
                report_frame[10] <= uart_results[3][15:8];
                report_frame[11] <= uart_results[3][7:0];
                report_frame[12] <= uart_results[4][15:8];
                report_frame[13] <= uart_results[4][7:0];
                report_frame[14] <= uart_results[5][15:8];
                report_frame[15] <= uart_results[5][7:0];
                report_frame[16] <= uart_results[6][15:8];
                report_frame[17] <= uart_results[6][7:0];
                report_frame[18] <= uart_results[7][15:8];
                report_frame[19] <= uart_results[7][7:0];
            end else if (report_sending) begin
                if (tx_ready && !tx_send) begin
                    tx_byte <= report_frame[report_idx];
                    tx_send <= 1'b1;
                    if (report_idx == 5'd19) begin
                        report_sending <= 1'b0; report_sent <= 1'b1;
                    end else
                        report_idx <= report_idx + 1;
                end
            end
        end
    end

endmodule
