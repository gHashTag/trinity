//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// TERNARY MATVEC ACCELERATOR — Top Level with Self-Test (v2: Sequential)
// =============================================================================
// First real AI computation on FPGA: 64x64 ternary matrix-vector multiply.
//
// Self-test at power-on:
//   - Weights: W[i][j] = +1 if (i+j)%3==0, -1 if (i+j)%3==1, 0 else
//   - Input: x[i] = i+1 (1..64)
//   - Expected: {43, -22, -21} repeating for j=0..63
//   - LED solid ON = PASSED, LED OFF = FAILED, LED blink = computing
//
// debug_state[0] = self_test_pass, debug_state[1] = computation_done
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module ternary_matvec_top (
    input  wire clk,
    input  wire uart_rx,
    output wire uart_tx,
    output wire led,
    output wire [1:0] debug_state
);

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
    // TERNARY MATVEC CORE
    // =====================================================================
    wire [15:0] mv_data;
    wire [5:0]  mv_addr;
    wire        mv_valid;
    wire        mv_done;
    wire        mv_busy;
    reg         mv_start;

    ternary_matvec core (
        .clk(clk),
        .rst(rst),
        .start(mv_start),
        .result_data(mv_data),
        .result_addr(mv_addr),
        .result_valid(mv_valid),
        .done(mv_done),
        .busy(mv_busy)
    );

    // =====================================================================
    // RESULT STORAGE — capture results as they come
    // =====================================================================
    reg [15:0] results [0:63];
    integer ri;

    always @(posedge clk) begin
        if (rst) begin
            for (ri = 0; ri < 64; ri = ri + 1)
                results[ri] <= 16'd0;
        end else if (mv_valid) begin
            results[mv_addr] <= mv_data;
        end
    end

    // =====================================================================
    // SELF-TEST STATE MACHINE
    // =====================================================================
    localparam ST_WAIT    = 3'd0;
    localparam ST_START   = 3'd1;
    localparam ST_COMPUTE = 3'd2;
    localparam ST_VERIFY  = 3'd3;
    localparam ST_PASS    = 3'd4;
    localparam ST_FAIL    = 3'd5;
    localparam ST_DONE    = 3'd6;

    reg [2:0]  st_state;
    reg        self_test_pass;
    reg        computation_done;
    reg [5:0]  verify_idx;
    reg [7:0]  wait_cnt;

    // Expected value: mod3-based pattern
    wire [6:0] v_mod3_full;
    assign v_mod3_full = {1'b0, verify_idx};

    wire signed [15:0] expected_val;
    assign expected_val = (v_mod3_full % 3 == 0) ? 16'sd43  :
                          (v_mod3_full % 3 == 1) ? -16'sd22 :
                                                   -16'sd21 ;

    always @(posedge clk) begin
        if (rst) begin
            st_state         <= ST_WAIT;
            self_test_pass   <= 1'b0;
            computation_done <= 1'b0;
            mv_start         <= 1'b0;
            verify_idx       <= 6'd0;
            wait_cnt         <= 8'd0;
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
                    mv_start <= 1'b1;
                    st_state <= ST_COMPUTE;
                end

                ST_COMPUTE: begin
                    if (mv_done) begin
                        computation_done <= 1'b1;
                        verify_idx <= 6'd0;
                        st_state <= ST_VERIFY;
                    end
                end

                ST_VERIFY: begin
                    if (results[verify_idx] != expected_val) begin
                        st_state <= ST_FAIL;
                    end else if (verify_idx == 6'd63) begin
                        st_state <= ST_PASS;
                    end else begin
                        verify_idx <= verify_idx + 1;
                    end
                end

                ST_PASS: begin
                    self_test_pass <= 1'b1;
                    st_state <= ST_DONE;
                end

                ST_FAIL: begin
                    self_test_pass <= 1'b0;
                    computation_done <= 1'b1;
                    st_state <= ST_DONE;
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
    // UART TX — sends self-test result (for future FTDI adapter)
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
    // UART REPORTER — sends 20-byte frame once
    // =====================================================================
    // [0xAA][0xBB][0x21][pass][y0h][y0l][y1h][y1l]...[y7h][y7l]

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
                report_frame[2]  <= 8'h21;
                report_frame[3]  <= {7'b0, self_test_pass};
                report_frame[4]  <= results[0][15:8];
                report_frame[5]  <= results[0][7:0];
                report_frame[6]  <= results[1][15:8];
                report_frame[7]  <= results[1][7:0];
                report_frame[8]  <= results[2][15:8];
                report_frame[9]  <= results[2][7:0];
                report_frame[10] <= results[3][15:8];
                report_frame[11] <= results[3][7:0];
                report_frame[12] <= results[4][15:8];
                report_frame[13] <= results[4][7:0];
                report_frame[14] <= results[5][15:8];
                report_frame[15] <= results[5][7:0];
                report_frame[16] <= results[6][15:8];
                report_frame[17] <= results[6][7:0];
                report_frame[18] <= results[7][15:8];
                report_frame[19] <= results[7][7:0];
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
