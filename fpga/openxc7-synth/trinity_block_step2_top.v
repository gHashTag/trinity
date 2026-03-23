//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// TRINITY BLOCK STEP 2 — MatVec1(243→729) + ReLU + MatVec2(729→243) + Self-Test
// =============================================================================
// Two-layer ternary MLP on FPGA:
//   matvec1(243→729) → ReLU → buffer[729] → matvec2(729→243) → verify
//
// Self-test at power-on:
//   - Input x[i] = i+1 (1..243)
//   - After matvec1: {-81, 162, -81} repeating
//   - After ReLU:    {0, 162, 0} repeating → stored in buffer
//   - After matvec2: {-39366, 0, 39366} repeating (k_mod3 = 0,1,2)
//   - LED solid ON = PASSED
//
// Resources: ~32 BRAM36, ~3K LUT, ~1.5K FF
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module trinity_block_step2_top (
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

    // Delay addr by 1 clock to align with ReLU
    reg [9:0] mv1_addr_d1;
    always @(posedge clk) begin
        mv1_addr_d1 <= mv1_addr;
    end

    // =====================================================================
    // INTERMEDIATE BUFFER — 729 x ACC_WIDTH (distributed RAM)
    // =====================================================================
    // Store ReLU output for matvec2 to read as input.
    // Power-of-2 size for clean addressing.
    localparam BUF_DEPTH = 1024;  // >= 729
    reg signed [ACC_WIDTH-1:0] relu_buffer [0:BUF_DEPTH-1];

    always @(posedge clk) begin
        if (relu_valid)
            relu_buffer[mv1_addr_d1] <= relu_data;
    end

    // Combinational read for matvec2 external input
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
    // UART RESULT BUFFER — first 8 final results
    // =====================================================================
    reg [ACC_WIDTH-1:0] uart_results [0:7];

    always @(posedge clk) begin
        if (mv2_valid && mv2_addr < 8'd8)
            uart_results[mv2_addr[2:0]] <= mv2_data;
    end

    // =====================================================================
    // SELF-TEST STATE MACHINE
    // =====================================================================
    // Expected matvec2 output: -39366, 0, 39366 repeating (k_mod3)
    localparam ST_WAIT     = 3'd0;
    localparam ST_START1   = 3'd1;
    localparam ST_LAYER1   = 3'd2;  // matvec1 + relu running, fill buffer
    localparam ST_START2   = 3'd3;
    localparam ST_LAYER2   = 3'd4;  // matvec2 running, verify output
    localparam ST_DONE     = 3'd5;

    reg [2:0]          st_state;
    reg                self_test_pass;
    reg                computation_done;
    reg [7:0]          wait_cnt;
    reg                verify_fail;
    reg [7:0]          check_count;
    reg [1:0]          k_mod3;

    // Expected output of matvec2
    wire signed [ACC_WIDTH-1:0] expected_val;
    assign expected_val = (k_mod3 == 2'd0) ? -20'sd39366 :
                          (k_mod3 == 2'd1) ?  20'sd0     :
                                              20'sd39366  ;

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
        end else begin
            mv1_start <= 1'b0;
            mv2_start <= 1'b0;

            case (st_state)
                ST_WAIT: begin
                    if (wait_cnt < 8'd20)
                        wait_cnt <= wait_cnt + 1;
                    else
                        st_state <= ST_START1;
                end

                ST_START1: begin
                    mv1_start <= 1'b1;
                    st_state  <= ST_LAYER1;
                end

                ST_LAYER1: begin
                    // Wait for matvec1 + ReLU to complete
                    // Buffer fills automatically via relu_valid
                    if (relu_done) begin
                        st_state <= ST_START2;
                    end
                end

                ST_START2: begin
                    k_mod3      <= 2'd0;
                    verify_fail <= 1'b0;
                    check_count <= 8'd0;
                    mv2_start   <= 1'b1;
                    st_state    <= ST_LAYER2;
                end

                ST_LAYER2: begin
                    if (mv2_valid) begin
                        if ($signed(mv2_data) != expected_val)
                            verify_fail <= 1'b1;
                        k_mod3 <= (k_mod3 == 2'd2) ? 2'd0 : k_mod3 + 2'd1;
                        check_count <= check_count + 8'd1;
                    end
                    if (mv2_done) begin
                        computation_done <= 1'b1;
                        self_test_pass <= ~verify_fail && (check_count == N2_OUT[7:0]);
                        st_state <= ST_DONE;
                    end
                end

                ST_DONE: st_state <= ST_DONE;
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
    // UART TX + REPORTER (same as step1, frame type 0x44)
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
                report_frame[2]  <= 8'h44;  // step2 frame type
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
