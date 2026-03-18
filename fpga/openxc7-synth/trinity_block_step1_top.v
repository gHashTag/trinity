// =============================================================================
// TRINITY BLOCK STEP 1 — MatVec(243->729) + ReLU + Self-Test
// =============================================================================
// First step toward full TrinityBlock on FPGA.
// Chain: matvec1(243->729) -> ReLU -> streaming verification
//
// Self-test at power-on:
//   - Weights: W[i][j] = +1 if (i+j)%3==0, -1 if (i+j)%3==1, 0 else
//   - Input: x[i] = i+1 (1..243)
//   - Pre-ReLU:  {-81, 162, -81} repeating
//   - Post-ReLU: {0, 162, 0} repeating
//   - LED solid ON = PASSED, LED OFF = FAILED, LED blink = computing
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module trinity_block_step1_top (
    input  wire clk,
    input  wire uart_rx,
    output wire uart_tx,
    output wire led,
    output wire [1:0] debug_state
);

    // =====================================================================
    // PARAMETERS
    // =====================================================================
    localparam N_IN       = 243;
    localparam N_OUT      = 729;
    localparam ACC_WIDTH  = 20;
    localparam J_WIDTH    = 10;

    // =====================================================================
    // INTERNAL POWER-ON RESET (255 clock cycles)
    // =====================================================================
    reg [7:0] por_counter = 8'd0;
    reg       rst = 1'b1;

    always @(posedge clk) begin
        if (por_counter < 8'd255) begin
            por_counter <= por_counter + 1;
            rst <= 1'b1;
        end else begin
            rst <= 1'b0;
        end
    end

    // =====================================================================
    // STAGE 1: TERNARY MATVEC BRAM CORE (243 -> 729)
    // =====================================================================
    wire signed [ACC_WIDTH-1:0] mv_data;
    wire [J_WIDTH-1:0]          mv_addr;
    wire                        mv_valid;
    wire                        mv_done;
    wire                        mv_busy;
    reg                         mv_start;

    ternary_matvec_bram #(
        .N_IN      (N_IN),
        .N_OUT     (N_OUT),
        .ACC_WIDTH (ACC_WIDTH),
        .ADDR_WIDTH(18),
        .I_WIDTH   (8),
        .J_WIDTH   (J_WIDTH),
        .MEM_FILE  ("fpga/openxc7-synth/ternary_matvec_243x729_weights.mem")
    ) matvec1 (
        .clk         (clk),
        .rst         (rst),
        .start       (mv_start),
        .result_data (mv_data),
        .result_addr (mv_addr),
        .result_valid(mv_valid),
        .done        (mv_done),
        .busy        (mv_busy)
    );

    // =====================================================================
    // STAGE 2: ReLU ACTIVATION
    // =====================================================================
    wire                        relu_valid;
    wire signed [ACC_WIDTH-1:0] relu_data;
    wire                        relu_done;

    ternary_activation #(
        .WIDTH(ACC_WIDTH)
    ) activation (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (mv_valid),
        .data_in   (mv_data),
        .done_in   (mv_done),
        .valid_out (relu_valid),
        .data_out  (relu_data),
        .done_out  (relu_done)
    );

    // Delay mv_addr by 1 clock to align with ReLU output
    reg [J_WIDTH-1:0] mv_addr_d1;
    always @(posedge clk) begin
        if (rst)
            mv_addr_d1 <= {J_WIDTH{1'b0}};
        else
            mv_addr_d1 <= mv_addr;
    end

    // =====================================================================
    // UART RESULT BUFFER — first 8 post-ReLU results
    // =====================================================================
    reg [ACC_WIDTH-1:0] uart_results [0:7];

    always @(posedge clk) begin
        if (relu_valid && mv_addr_d1 < 10'd8) begin
            uart_results[mv_addr_d1[2:0]] <= relu_data;
        end
    end

    // =====================================================================
    // STREAMING SELF-TEST — verify post-ReLU values
    // =====================================================================
    // Pre-ReLU:  -81, 162, -81 repeating (j_mod3 = 0,1,2)
    // Post-ReLU:   0, 162,   0 repeating
    localparam ST_WAIT    = 2'd0;
    localparam ST_START   = 2'd1;
    localparam ST_COMPUTE = 2'd2;
    localparam ST_DONE    = 2'd3;

    reg [1:0]           st_state;
    reg                 self_test_pass;
    reg                 computation_done;
    reg [7:0]           wait_cnt;

    // Streaming verification registers
    reg                 verify_fail;
    reg [J_WIDTH-1:0]   check_count;
    reg [1:0]           j_mod3;

    // Expected post-ReLU values
    wire signed [ACC_WIDTH-1:0] expected_val;
    assign expected_val = (j_mod3 == 2'd1) ? 20'sd162 : 20'sd0;

    always @(posedge clk) begin
        if (rst) begin
            st_state         <= ST_WAIT;
            self_test_pass   <= 1'b0;
            computation_done <= 1'b0;
            mv_start         <= 1'b0;
            wait_cnt         <= 8'd0;
            verify_fail      <= 1'b0;
            check_count      <= {J_WIDTH{1'b0}};
            j_mod3           <= 2'd0;
        end else begin
            mv_start <= 1'b0;

            case (st_state)
                ST_WAIT: begin
                    if (wait_cnt < 8'd20)
                        wait_cnt <= wait_cnt + 1;
                    else
                        st_state <= ST_START;
                end

                ST_START: begin
                    j_mod3      <= 2'd0;
                    verify_fail <= 1'b0;
                    check_count <= {J_WIDTH{1'b0}};
                    mv_start    <= 1'b1;
                    st_state    <= ST_COMPUTE;
                end

                ST_COMPUTE: begin
                    // Check each post-ReLU result as it arrives
                    if (relu_valid) begin
                        if (relu_data != expected_val)
                            verify_fail <= 1'b1;
                        // Advance mod3 counter
                        j_mod3 <= (j_mod3 == 2'd2) ? 2'd0 : j_mod3 + 2'd1;
                        check_count <= check_count + {{(J_WIDTH-1){1'b0}}, 1'b1};
                    end
                    if (relu_done) begin
                        computation_done <= 1'b1;
                        self_test_pass <= ~verify_fail && (check_count == N_OUT[J_WIDTH-1:0]);
                        st_state <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    st_state <= ST_DONE;
                end
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
            if (st_state == ST_DONE) begin
                led_state <= self_test_pass;
            end else if (led_counter == 25'd6_250_000) begin
                led_counter <= 25'd0;
                led_state <= ~led_state;
            end
        end
    end

    assign led = ~led_state;

    // =====================================================================
    // DEBUG STATE
    // =====================================================================
    assign debug_state[0] = self_test_pass;
    assign debug_state[1] = computation_done;

    // =====================================================================
    // UART TX — sends self-test result
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
            tx_active    <= 1'b0;
            uart_tx_reg  <= 1'b1;
            baud_counter <= 16'd0;
            tx_bit_idx   <= 4'd0;
        end else if (!tx_active && tx_send) begin
            tx_active    <= 1'b1;
            tx_shift     <= tx_byte;
            uart_tx_reg  <= 1'b0;
            baud_counter <= 16'd0;
            tx_bit_idx   <= 4'd0;
        end else if (tx_active) begin
            if (baud_counter < CLK_DIV - 1) begin
                baud_counter <= baud_counter + 1;
            end else begin
                baud_counter <= 16'd0;
                if (tx_bit_idx < 4'd8) begin
                    uart_tx_reg <= tx_shift[0];
                    tx_shift    <= {1'b0, tx_shift[7:1]};
                    tx_bit_idx  <= tx_bit_idx + 1;
                end else if (tx_bit_idx == 4'd8) begin
                    uart_tx_reg <= 1'b1;
                    tx_bit_idx  <= tx_bit_idx + 1;
                end else begin
                    tx_active   <= 1'b0;
                    uart_tx_reg <= 1'b1;
                end
            end
        end
    end

    // =====================================================================
    // UART REPORTER — 20-byte frame
    // =====================================================================
    // Frame: [0xAA][0xBB][0x43][pass][y0h][y0l]...[y7h][y7l]
    // 0x43 = frame type for step1 (matvec+relu)

    reg       report_sent;
    reg       report_sending;
    reg [4:0] report_idx;
    reg [7:0] report_frame [0:19];

    always @(posedge clk) begin
        if (rst) begin
            report_sent    <= 1'b0;
            report_sending <= 1'b0;
            report_idx     <= 5'd0;
            tx_send        <= 1'b0;
        end else begin
            tx_send <= 1'b0;

            if (!report_sent && st_state == ST_DONE && !report_sending) begin
                report_sending <= 1'b1;
                report_idx     <= 5'd0;
                report_frame[0]  <= 8'hAA;
                report_frame[1]  <= 8'hBB;
                report_frame[2]  <= 8'h43;  // step1 frame type
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
                        report_sending <= 1'b0;
                        report_sent    <= 1'b1;
                    end else begin
                        report_idx <= report_idx + 1;
                    end
                end
            end
        end
    end

endmodule
