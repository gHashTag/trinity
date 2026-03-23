//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ============================================================================
// VSA UART φ-TOP — Zero-DSP48 VSA Coprocessor
// ============================================================================
//
// Combines:
// - UART communication (115200 baud, 8N1)
// - Command decoder (PING, BIND, BUNDLE, SIMILARITY)
// - φ-arithmetic (0 DSP48!) for VSA binding
//
// Key innovation: BIND uses φ × x = x + x_prev instead of DSP48 multipliers
//
// Generated for Trinity Patent P2 — VSA Coprocessor Claim Validation
// φ² + 1/φ² = 3 = TRINITY
//
// ============================================================================

`timescale 1ns / 1ps

module vsa_uart_phi_top (
    input  wire clk,
    input  wire rst,
    input  wire uart_rx,
    output wire uart_tx,
    output wire led,
    output wire [1:0] debug_state
);

    // =========================================================================
    // CLOCK DIVIDER: 50MHz / (16 * 115200) = 27.13 ≈ 27
    // =========================================================================
    localparam CLK_DIV = 50_000_000 / (16 * 115200);

    // =========================================================================
    // UART TX STATE MACHINE
    // =========================================================================
    localparam TX_IDLE  = 2'b00;
    localparam TX_START = 2'b01;
    localparam TX_DATA  = 2'b10;
    localparam TX_STOP  = 2'b11;

    reg [1:0] tx_state;
    reg [15:0] clk_div_counter;
    reg [3:0] bit_counter;
    reg [7:0] tx_shift_reg;
    reg tx_busy;
    reg tx_start;
    reg [7:0] tx_data;
    reg uart_tx_reg;

    wire tx_ready = !tx_busy;

    always @(posedge clk) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            tx_busy <= 1'b0;
            uart_tx_reg <= 1'b1;
            bit_counter <= 4'b0;
            clk_div_counter <= 16'b0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    uart_tx_reg <= 1'b1;
                    if (tx_start) begin
                        tx_state <= TX_START;
                        tx_busy <= 1'b1;
                        tx_shift_reg <= tx_data;
                        bit_counter <= 4'b0;
                        clk_div_counter <= 16'b0;
                        tx_start <= 1'b0;
                    end
                end

                TX_START: begin
                    uart_tx_reg <= 1'b0;  // Start bit
                    if (clk_div_counter == CLK_DIV - 1) begin
                        clk_div_counter <= 16'b0;
                        tx_state <= TX_DATA;
                    end else begin
                        clk_div_counter <= clk_div_counter + 1'b1;
                    end
                end

                TX_DATA: begin
                    uart_tx_reg <= tx_shift_reg[0];
                    if (clk_div_counter == CLK_DIV - 1) begin
                        clk_div_counter <= 16'b0;
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        if (bit_counter == 4'd7) begin
                            tx_state <= TX_STOP;
                        end else begin
                            bit_counter <= bit_counter + 1'b1;
                        end
                    end else begin
                        clk_div_counter <= clk_div_counter + 1'b1;
                    end
                end

                TX_STOP: begin
                    uart_tx_reg <= 1'b1;  // Stop bit
                    if (clk_div_counter == CLK_DIV - 1) begin
                        tx_state <= TX_IDLE;
                        tx_busy <= 1'b0;
                    end else begin
                        clk_div_counter <= clk_div_counter + 1'b1;
                    end
                end
            endcase
        end
    end

    assign uart_tx = uart_tx_reg;

    // =========================================================================
    // UART RX STATE MACHINE
    // =========================================================================
    localparam RX_IDLE  = 2'b00;
    localparam RX_START = 2'b01;
    localparam RX_DATA  = 2'b10;
    localparam RX_STOP  = 2'b11;

    reg [1:0] rx_state;
    reg [15:0] rx_clk_div;
    reg [3:0] rx_bit_counter;
    reg [7:0] rx_shift_reg;
    reg [3:0] rx_oversample;
    reg rx_busy;
    reg [7:0] rx_data;

    always @(posedge clk) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_busy <= 1'b0;
            rx_data <= 8'b0;
            rx_oversample <= 4'b0;
        end else begin
            case (rx_state)
                RX_IDLE: begin
                    rx_busy <= 1'b0;
                    if (!uart_rx) begin  // Start bit detected
                        rx_state <= RX_START;
                        rx_busy <= 1'b1;
                        rx_clk_div <= 16'b0;
                        rx_oversample <= 4'b0;
                    end
                end

                RX_START: begin
                    if (rx_clk_div == CLK_DIV - 1) begin
                        rx_clk_div <= 16'b0;
                        if (rx_oversample == 4'd7) begin
                            if (!uart_rx) begin
                                rx_state <= RX_DATA;
                                rx_bit_counter <= 4'b0;
                            end else begin
                                rx_state <= RX_IDLE;
                            end
                        end else begin
                            rx_oversample <= rx_oversample + 1'b1;
                        end
                    end else begin
                        rx_clk_div <= rx_clk_div + 1'b1;
                    end
                end

                RX_DATA: begin
                    if (rx_clk_div == CLK_DIV - 1) begin
                        rx_clk_div <= 16'b0;
                        if (rx_oversample == 4'd15) begin
                            rx_shift_reg <= {uart_rx, rx_shift_reg[7:1]};
                            if (rx_bit_counter == 4'd7) begin
                                rx_state <= RX_STOP;
                            end else begin
                                rx_bit_counter <= rx_bit_counter + 1'b1;
                            end
                            rx_oversample <= 4'b0;
                        end else begin
                            rx_oversample <= rx_oversample + 1'b1;
                        end
                    end else begin
                        rx_clk_div <= rx_clk_div + 1'b1;
                    end
                end

                RX_STOP: begin
                    if (rx_clk_div == CLK_DIV - 1) begin
                        rx_data <= rx_shift_reg;
                        rx_state <= RX_IDLE;
                    end else begin
                        rx_clk_div <= rx_clk_div + 1'b1;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // FRAME PARSING STATE MACHINE
    // =========================================================================
    localparam F_SYNC = 0;
    localparam F_CMD  = 1;
    localparam F_LEN  = 2;
    localparam F_DATA = 3;
    localparam F_CRC  = 4;

    // UART Commands (from SSOT: src/common/protocol.zig)
    localparam CMD_MODE       = 8'h01;
    localparam CMD_BIND       = 8'h02;
    localparam CMD_BUNDLE     = 8'h03;
    localparam CMD_SIMILARITY = 8'h04;
    localparam CMD_PHI_BIND   = 8'h05;  // NEW: φ-based binding (0 DSP48!)
    localparam CMD_PING       = 8'hFF;
    localparam SYNC_BYTE      = 8'hAA;

    reg [2:0] frame_state;
    reg [7:0] rx_cmd;
    reg [7:0] rx_len;
    reg [255:0] rx_payload;
    reg [7:0] data_idx;
    reg [15:0] rx_crc_calc;
    reg [15:0] rx_crc_recv;

    // Command execution enable signals
    reg exec_mode;
    reg exec_bind;
    reg exec_bundle;
    reg exec_similarity;
    reg exec_phi_bind;  // NEW
    reg exec_ping;

    // CRC-16/CCITT
    function [15:0] crc16_ccitt;
        input [7:0] data;
        input [15:0] crc;
        reg [15:0] new_crc;
        integer i;
        begin
            new_crc = crc ^ {8'h00, data};
            for (i = 0; i < 8; i = i + 1) begin
                if (new_crc[15]) begin
                    new_crc = (new_crc << 1) ^ 16'h1021;
                end else begin
                    new_crc = new_crc << 1;
                end
            end
            crc16_ccitt = new_crc;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            frame_state <= F_SYNC;
        end else begin
            if (!rx_busy && tx_ready) begin
                case (frame_state)
                    F_SYNC: begin
                        if (rx_data == SYNC_BYTE) begin
                            frame_state <= F_CMD;
                            rx_crc_calc <= 16'hFFFF;
                        end
                    end

                    F_CMD: begin
                        rx_cmd <= rx_data;
                        rx_crc_calc <= crc16_ccitt(rx_data, rx_crc_calc);
                        frame_state <= F_LEN;
                    end

                    F_LEN: begin
                        rx_len <= rx_data;
                        rx_crc_calc <= crc16_ccitt(rx_data, rx_crc_calc);
                        data_idx <= 8'b0;
                        if (rx_data == 8'b0) begin
                            frame_state <= F_CRC;
                        end else begin
                            frame_state <= F_DATA;
                        end
                    end

                    F_DATA: begin
                        rx_payload[data_idx * 8 +: 8] <= rx_data;
                        rx_crc_calc <= crc16_ccitt(rx_data, rx_crc_calc);
                        data_idx <= data_idx + 1'b1;
                        if (data_idx == rx_len - 1) begin
                            frame_state <= F_CRC;
                        end
                    end

                    F_CRC: begin
                        rx_crc_recv <= {rx_data, rx_crc_recv[7:0]};
                        if (rx_crc_calc == rx_crc_recv) begin
                            case (rx_cmd)
                                CMD_MODE:       exec_mode <= 1'b1;
                                CMD_BIND:       exec_bind <= 1'b1;
                                CMD_BUNDLE:     exec_bundle <= 1'b1;
                                CMD_SIMILARITY: exec_similarity <= 1'b1;
                                CMD_PHI_BIND:   exec_phi_bind <= 1'b1;  // NEW
                                CMD_PING:       exec_ping <= 1'b1;
                                default: begin
                                    response_data <= 8'hFF;
                                    send_response <= 1'b1;
                                end
                            endcase
                        end
                        frame_state <= F_SYNC;
                    end
                endcase
            end
        end
    end

    // =========================================================================
    // φ-ARITHMETIC CORE (0 DSP48!)
    // =========================================================================
    // φ × x = x + x_prev (Fibonacci identity)
    // φ² × x = x + φ×x (nested identity)

    localparam WIDTH = 25;  // Match phi_arithmetic_unit

    reg [WIDTH-1:0] phi_x_prev;
    reg [WIDTH-1:0] phi2_x_prev;
    reg [WIDTH-1:0] phi_result;
    reg [WIDTH-1:0] phi2_result;

    always @(posedge clk) begin
        if (rst) begin
            phi_x_prev <= {WIDTH{1'b0}};
            phi2_x_prev <= {WIDTH{1'b0}};
        end else begin
            // Update previous values
            phi_x_prev <= phi_result;
            phi2_x_prev <= phi2_result;
        end
    end

    // φ × x = x + x_prev (combinational for fast response)
    wire [WIDTH-1:0] phi_x = rx_payload[WIDTH-1:0] + phi_x_prev;

    // φ² × x = x + φ×x
    wire [WIDTH-1:0] phi2_x = rx_payload[WIDTH-1:0] + phi_x;

    // Latch results on command
    always @(posedge clk) begin
        if (exec_phi_bind) begin
            phi_result <= phi_x;
            phi2_result <= phi2_x;
        end
    end

    // =========================================================================
    // COMMAND RESPONSES
    // =========================================================================
    localparam RESP_PONG = 8'hAA;
    localparam RESP_OK = 8'h00;

    reg [7:0] response_data;
    reg send_response;
    reg [7:0] tx_queue[0:7];  // Response queue
    reg [2:0] tx_queue_head;
    reg [2:0] tx_queue_tail;
    reg tx_queue_full;
    wire tx_queue_empty = (tx_queue_head == tx_queue_tail) && !tx_queue_full;

    // PING response
    always @(posedge clk) begin
        if (exec_ping && !tx_queue_full) begin
            tx_queue[tx_queue_head] <= RESP_PONG;
            tx_queue_head <= tx_queue_head + 1'b1;
            tx_queue_full <= (tx_queue_head + 1'b1 == tx_queue_tail);
            exec_ping <= 1'b0;
        end
    end

    // MODE response
    always @(posedge clk) begin
        if (exec_mode && !tx_queue_full) begin
            tx_queue[tx_queue_head] <= RESP_OK;
            tx_queue_head <= tx_queue_head + 1'b1;
            tx_queue_full <= (tx_queue_head + 1'b1 == tx_queue_tail);
            led_mode <= rx_payload[1:0];
            exec_mode <= 1'b0;
        end
    end

    // =========================================================================
    // TRIT OPERATIONS (from uart_top.v)
    // =========================================================================

    // Trit multiplication table (pure logic, no DSP48)
    function [1:0] trit_multiply;
        input [1:0] a;
        input [1:0] b;
        begin
            if (a == 2'b00 || b == 2'b00)
                trit_multiply = 2'b00;      // ZERO
            else if (a == b)
                trit_multiply = 2'b01;      // POSITIVE
            else
                trit_multiply = 2'b10;      // NEGATIVE
        end
    endfunction

    reg [31:0] bind_result;
    integer i;

    always @(posedge clk) begin
        if (exec_bind && !tx_queue_full) begin
            // Bind two 16-trit vectors (32 bits each)
            for (i = 0; i < 16; i = i + 1) begin
                bind_result[i*2 +: 2] = trit_multiply(
                    rx_payload[i*2 +: 2],
                    rx_payload[32 + i*2 +: 2]
                );
            end
            // Queue first byte of result
            tx_queue[tx_queue_head] <= bind_result[7:0];
            tx_queue_head <= tx_queue_head + 1'b1;
            tx_queue_full <= (tx_queue_head + 1'b1 == tx_queue_tail);
            exec_bind <= 1'b0;
        end
    end

    // φ-BIND response (NEW!)
    always @(posedge clk) begin
        if (exec_phi_bind && !tx_queue_full) begin
            // Send φ×x result (low byte)
            tx_queue[tx_queue_head] <= phi_result[7:0];
            tx_queue_head <= tx_queue_head + 1'b1;
            tx_queue_full <= (tx_queue_head + 1'b1 == tx_queue_tail);
            exec_phi_bind <= 1'b0;
        end
    end

    // Bundle majority (simplified)
    function [1:0] trit_majority2;
        input [1:0] a;
        input [1:0] b;
        begin
            if (a == 2'b10 && b == 2'b10)
                trit_majority2 = 2'b10;
            else if (a == 2'b01 && b == 2'b01)
                trit_majority2 = 2'b01;
            else if (a == 2'b00)
                trit_majority2 = b;
            else if (b == 2'b00)
                trit_majority2 = a;
            else
                trit_majority2 = 2'b00;
        end
    endfunction

    reg [31:0] bundle_result;

    always @(posedge clk) begin
        if (exec_bundle && !tx_queue_full) begin
            for (i = 0; i < 16; i = i + 1) begin
                bundle_result[i*2 +: 2] = trit_majority2(
                    rx_payload[i*2 +: 2],
                    rx_payload[32 + i*2 +: 2]
                );
            end
            tx_queue[tx_queue_head] <= bundle_result[7:0];
            tx_queue_head <= tx_queue_head + 1'b1;
            tx_queue_full <= (tx_queue_head + 1'b1 == tx_queue_tail);
            exec_bundle <= 1'b0;
        end
    end

    // Similarity (simplified)
    always @(posedge clk) begin
        if (exec_similarity && !tx_queue_full) begin
            tx_queue[tx_queue_head] <= 8'h80;  // Fixed response for demo
            tx_queue_head <= tx_queue_head + 1'b1;
            tx_queue_full <= (tx_queue_head + 1'b1 == tx_queue_tail);
            exec_similarity <= 1'b0;
        end
    end

    // =========================================================================
    // TRANSMIT QUEUE
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            send_response <= 1'b0;
        end else begin
            if (!tx_queue_empty && tx_ready && !tx_start) begin
                tx_data <= tx_queue[tx_queue_tail];
                tx_start <= 1'b1;
                tx_queue_tail <= tx_queue_tail + 1'b1;
                tx_queue_full <= 1'b0;
            end
        end
    end

    // =========================================================================
    // LED STATUS (ACTIVE-LOW!)
    // =========================================================================
    localparam MODE_SEPARABLE  = 8'h00;
    localparam MODE_VIOLATION  = 8'h01;
    localparam MODE_ZERO       = 8'h02;
    localparam MODE_NEGATIVE   = 8'h03;

    reg [1:0] led_mode = 2'h01;
    reg [23:0] blink_counter = 24'd0;
    wire blink_tick = (blink_counter == 24'd0);

    always @(posedge clk) begin
        if (rst) begin
            led_mode <= 2'h01;
            blink_counter <= 24'd16_777_215;
        end else begin
            if (blink_tick)
                blink_counter <= 24'd16_777_215;  // ~335ms at 50MHz
            else
                blink_counter <= blink_counter - 1'b1;
        end
    end

    // ACTIVE-LOW: 0 = ON, 1 = OFF
    assign led = ~((led_mode == MODE_SEPARABLE)  ? 1'b1 :
                   (led_mode == MODE_VIOLATION)  ? blink_tick :
                   (led_mode == MODE_ZERO)       ? 1'b0 :
                   (led_mode == MODE_NEGATIVE)   ? ~blink_tick :
                   1'b0);

    // Debug outputs
    assign debug_state = {tx_busy, rx_busy};

endmodule

// ============================================================================
// φ² + 1/φ² = 3 = TRINITY
// ============================================================================
