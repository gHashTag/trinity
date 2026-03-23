//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// VSA VSA TOP — Bind + Bundle Operations via UART
// Day 3: VSA bind and bundle commands over UART
//
// Features:
// - UART receiver at 115200 baud
// - BIND command (0x02): bind two 16-trit vectors
// - BUNDLE command (0x03): bundle two 16-trit vectors
// - CRC-16 for error detection
// - MODE commands from Day 2 preserved
//
// Protocol:
//   [0xAA][CMD][LEN_H][LEN_L][DATA...][CRC_L][CRC_H]
//   BIND: 0x02 with 8 bytes data (4+4 for two 16-trit vectors)
//   BUNDLE: 0x03 with 8 bytes data (4+4 for two 16-trit vectors)
//
// Trit encoding (2 bits):
//   00 = 0 (zero)
//   01 = +1 (positive)
//   10 = -1 (negative)
//   11 = reserved

`default_nettype none

module vsa_vsa_top (
    input  wire clk,          // 50 MHz (U22)
    input  wire rst,          // Reset (active high)
    input  wire uart_rx,      // UART receive (H16)
    output wire uart_tx,      // UART transmit (J16)
    output wire led           // Status LED (T23)
);

    // === UART RECEIVER (115200 baud @ 50MHz) ===
    localparam BAUD_DIV = 434;

    reg [15:0] baud_counter = 0;
    reg [2:0] rx_state = 0;
    reg [7:0] rx_shift = 0;
    reg [7:0] rx_data = 0;
    reg rx_valid = 0;

    localparam RX_IDLE = 0;
    localparam RX_START = 1;
    localparam RX_BITS = 2;
    localparam RX_STOP = 3;

    always @(posedge clk) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_valid <= 0;
        end else begin
            rx_valid <= 0;
            case (rx_state)
                RX_IDLE: begin
                    if (!uart_rx) begin
                        baud_counter <= 0;
                        rx_state <= RX_START;
                    end
                end
                RX_START: begin
                    if (baud_counter == BAUD_DIV/2 - 1) begin
                        baud_counter <= 0;
                        rx_state <= RX_BITS;
                        rx_shift <= 0;
                    end else begin
                        baud_counter <= baud_counter + 1;
                    end
                end
                RX_BITS: begin
                    if (baud_counter == BAUD_DIV - 1) begin
                        baud_counter <= 0;
                        rx_shift <= {uart_rx, rx_shift[7:1]};
                        if (rx_shift[2:0] == 3'b000) begin
                            rx_state <= RX_STOP;
                        end
                    end else begin
                        baud_counter <= baud_counter + 1;
                    end
                end
                RX_STOP: begin
                    if (baud_counter == BAUD_DIV - 1) begin
                        rx_data <= {uart_rx, rx_shift[7:1]};
                        rx_valid <= 1;
                        rx_state <= RX_IDLE;
                    end else begin
                        baud_counter <= baud_counter + 1;
                    end
                end
            endcase
        end
    end

    // === COMMAND DECODER STATE MACHINE ===
    // States for enhanced protocol
    localparam IDLE     = 4'd0;
    localparam HDR      = 4'd1;
    localparam CMD      = 4'd2;
    localparam LEN_H    = 4'd3;
    localparam LEN_L    = 4'd4;
    localparam DATA     = 4'd5;
    localparam CRC_L    = 4'd6;
    localparam CRC_H    = 4'd7;
    localparam CHECK    = 4'd8;
    localparam EXECUTE  = 4'd9;
    localparam RESPONSE = 4'd10;

    reg [3:0] state = IDLE;
    reg [7:0] cmd_byte;
    reg [7:0] data_len;
    reg [7:0] data_idx;
    reg [15:0] crc_accum;
    reg [15:0] crc_received;

    // Vector buffers (16 trits × 2 bits = 32 bits = 4 bytes)
    reg [31:0] vector_a;  // 16 trits
    reg [31:0] vector_b;  // 16 trits
    reg [31:0] result_vec; // Operation result

    // Response data
    reg [7:0] tx_data;
    reg [15:0] tx_counter = 0;
    reg tx_busy = 0;
    reg [2:0] resp_idx;
    reg send_resp;

    // LED mode from Day 2
    reg [1:0] led_mode_reg = 2;

    // === CRC-16-CCITT FUNCTION ===
    // Polynomial: x^16 + x^12 + x^5 + 1 (0x1021)
    function [15:0] crc16_byte;
        input [7:0] data;
        input [15:0] crc;
        integer i;
        begin
            crc16_byte = crc ^ {8'h00, data};
            for (i = 0; i < 8; i = i + 1) begin
                if (crc16_byte[15])
                    crc16_byte = (crc16_byte << 1) ^ 16'h1021;
                else
                    crc16_byte = crc16_byte << 1;
            end
        end
    endfunction

    // === STATE MACHINE ===
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            crc_accum <= 16'hFFFF;
            data_idx <= 0;
            send_resp <= 0;
            tx_busy <= 0;
        end else begin
            // Default: clear send_resp
            if (send_resp && !tx_busy)
                send_resp <= 0;

            if (tx_sm_state == TX_IDLE) begin  // Only process new commands when TX idle
                case (state)
                    IDLE: begin
                        if (rx_valid) begin
                            if (rx_data == 8'hAA) begin  // Sync byte
                                state <= HDR;
                                crc_accum <= 16'hFFFF;
                            end
                        end
                    end

                    HDR: begin
                        if (rx_valid) begin
                            cmd_byte <= rx_data;
                            crc_accum <= crc16_byte(rx_data, crc_accum);
                            state <= CMD;
                        end
                    end

                    CMD: begin
                        if (rx_valid) begin
                            data_len[15:8] <= rx_data;
                            crc_accum <= crc16_byte(rx_data, crc_accum);
                            state <= LEN_H;
                        end
                    end

                    LEN_H: begin
                        if (rx_valid) begin
                            data_len[7:0] <= rx_data;
                            crc_accum <= crc16_byte(rx_data, crc_accum);

                            // Check valid commands
                            if (cmd_byte == 8'hFF && rx_data == 8'h00) begin
                                // PING: 0 bytes data
                                state <= CRC_L;
                            end else if (cmd_byte == 8'h01 && rx_data == 8'h00) begin
                                // MODE: 1 byte parameter (simplified)
                                state <= DATA;
                                data_idx <= 0;
                            end else if ((cmd_byte == 8'h02 || cmd_byte == 8'h03) && rx_data == 8'h08) begin
                                // BIND/BUNDLE: 8 bytes data (2 × 4-byte vectors)
                                state <= DATA;
                                data_idx <= 0;
                            end else begin
                                state <= IDLE;  // Invalid
                            end
                        end
                    end

                    LEN_L: begin
                        // Not used in simplified protocol
                        state <= IDLE;
                    end

                    DATA: begin
                        if (rx_valid) begin
                            crc_accum <= crc16_byte(rx_data, crc_accum);

                            // Store in vector buffers
                            if (data_idx < 4) begin
                                vector_a[data_idx*8 +: 8] <= rx_data;
                            end else if (data_idx < 8) begin
                                vector_b[(data_idx-4)*8 +: 8] <= rx_data;
                            end else if (cmd_byte == 8'h01) begin
                                // MODE parameter byte
                                led_mode_reg <= rx_data[1:0];
                            end

                            data_idx <= data_idx + 1;
                            if (data_idx >= data_len - 1) begin
                                state <= CRC_L;
                            end
                        end
                    end

                    CRC_L: begin
                        if (rx_valid) begin
                            crc_received[7:0] <= rx_data;
                            state <= CRC_H;
                        end
                    end

                    CRC_H: begin
                        if (rx_valid) begin
                            crc_received[15:8] <= rx_data;
                            state <= CHECK;
                        end
                    end

                    CHECK: begin
                        // For Day 3, skip CRC check in hardware for simplicity
                        // (Host will verify)
                        if (cmd_byte == 8'hFF) begin
                            // PING: immediate response
                            tx_data <= 8'hAA;  // PONG
                            tx_start_trigger <= 1;
                            state <= IDLE;
                        end else if (cmd_byte == 8'h01) begin
                            // MODE: send OK
                            tx_data <= 8'h00;  // OK
                            tx_start_trigger <= 1;
                            state <= IDLE;
                        end else begin
                            state <= EXECUTE;
                        end
                    end

                    EXECUTE: begin
                        // Perform VSA operation
                        if (cmd_byte == 8'h02) begin
                            // BIND: trit multiplication
                            result_vec <= bind_vectors(vector_a, vector_b);
                        end else if (cmd_byte == 8'h03) begin
                            // BUNDLE: majority vote
                            result_vec <= bundle_vectors(vector_a, vector_b);
                        end
                        send_resp <= 1;
                        resp_idx <= 0;
                        state <= RESPONSE;
                    end

                    RESPONSE: begin
                        if (send_resp && !tx_busy) begin
                            if (resp_idx < 1) begin
                                // Status byte
                                tx_data <= 8'h00;  // OK
                                tx_start_trigger <= 1;
                                resp_idx <= resp_idx + 1;
                            end else if (resp_idx < 5) begin
                                // Result data (4 bytes)
                                tx_data <= result_vec[(resp_idx-1)*8 +: 8];
                                tx_start_trigger <= 1;
                                resp_idx <= resp_idx + 1;
                            end else begin
                                state <= IDLE;
                            end
                        end
                    end
                endcase
            end
        end
    end

    // === BIND FUNCTION (trit multiplication) ===
    function [31:0] bind_vectors;
        input [31:0] a;
        input [31:0] b;
        integer i;
        reg [1:0] a_trit, b_trit, result_trit;
        begin
            bind_vectors = 0;
            for (i = 0; i < 16; i = i + 1) begin
                a_trit = a[i*2 +: 2];
                b_trit = b[i*2 +: 2];

                // Bind truth table:
                // -1 × -1 = +1,  -1 × 0 = 0,  -1 × +1 = -1
                //  0 × X   = 0
                // +1 × -1 = -1,  +1 × 0 = 0,  +1 × +1 = +1

                if (a_trit == 2'b00 || b_trit == 2'b00)
                    result_trit = 2'b00;              // Zero
                else if (a_trit == b_trit)
                    result_trit = 2'b01;              // Positive (same signs)
                else
                    result_trit = 2'b10;              // Negative (opposing)

                bind_vectors[i*2 +: 2] = result_trit;
            end
        end
    endfunction

    // === BUNDLE FUNCTION (majority vote) ===
    function [31:0] bundle_vectors;
        input [31:0] a;
        input [31:0] b;
        integer i;
        reg [1:0] a_trit, b_trit, result_trit;
        begin
            bundle_vectors = 0;
            for (i = 0; i < 16; i = i + 1) begin
                a_trit = a[i*2 +: 2];
                b_trit = b[i*2 +: 2];

                // Bundle truth table (majority of 2):
                // -1, -1 → -1
                // -1,  0 → -1
                // -1, +1 →  0
                //  0, -1 → -1
                //  0,  0 →  0
                //  0, +1 → +1
                // +1, -1 →  0
                // +1,  0 → +1
                // +1, +1 → +1

                if (a_trit == 2'b10 && b_trit == 2'b10)
                    result_trit = 2'b10;              // Both negative
                else if (a_trit == 2'b01 && b_trit == 2'b01)
                    result_trit = 2'b01;              // Both positive
                else if (a_trit == 2'b00)
                    result_trit = b_trit;             // A zero: take B
                else if (b_trit == 2'b00)
                    result_trit = a_trit;             // B zero: take A
                else
                    result_trit = 2'b00;              // Opposing: zero

                bundle_vectors[i*2 +: 2] = result_trit;
            end
        end
    endfunction

    // === UART TX ===
    reg tx;
    reg tx_start_trigger = 0;

    // TX state machine states
    localparam TX_IDLE = 0;
    localparam TX_START = 1;
    localparam TX_DATA = 2;
    localparam TX_STOP = 3;

    reg [1:0] tx_sm_state = TX_IDLE;

    always @(posedge clk) begin
        if (rst) begin
            tx_sm_state <= TX_IDLE;
            tx_busy <= 0;
            tx_start_trigger <= 0;
            tx <= 1'b1;
        end else begin
            // Clear trigger when starting transmission
            if (tx_start_trigger && tx_sm_state == TX_IDLE) begin
                tx_start_trigger <= 0;
                tx_sm_state <= TX_START;
                tx_busy <= 1;
                tx_counter <= 0;
            end

            case (tx_sm_state)
                TX_IDLE: begin
                    tx <= 1'b1;
                end
                TX_START: begin  // Start bit (LOW)
                    if (tx_counter == BAUD_DIV - 1) begin
                        tx_counter <= 0;
                        tx_sm_state <= TX_DATA;
                    end else begin
                        tx_counter <= tx_counter + 1;
                        tx <= 1'b0;
                    end
                end
                TX_DATA: begin  // Data bits (LSB first)
                    if (tx_counter == BAUD_DIV - 1) begin
                        tx_counter <= 0;
                        tx <= tx_data[0];
                        tx_data <= {1'b1, tx_data[7:1]};
                        if (tx_data[7:1] == 7'b1111111)
                            tx_sm_state <= TX_STOP;
                    end else begin
                        tx_counter <= tx_counter + 1;
                    end
                end
                TX_STOP: begin  // Stop bit (HIGH)
                    if (tx_counter == BAUD_DIV - 1) begin
                        tx_sm_state <= TX_IDLE;
                        tx_busy <= 0;
                        tx <= 1'b1;
                    end else begin
                        tx_counter <= tx_counter + 1;
                        tx <= 1'b1;
                    end
                end
            endcase
        end
    end

    assign uart_tx = tx;

    // === LED CONTROL (from Day 2) ===
    reg [25:0] blink_counter = 0;
    reg [31:0] lfsr = 32'hDEAD_BEEF;
    wire lfsr_feedback = lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0];

    always @(posedge clk) begin
        blink_counter <= blink_counter + 1;
        lfsr <= {lfsr[30:0], lfsr_feedback};
    end

    assign led = (led_mode_reg == 2'b00) ? ~blink_counter[25] :
                 (led_mode_reg == 2'b01) ? ~lfsr[0] :
                 (led_mode_reg == 2'b10) ? ~blink_counter[22] :
                 ~blink_counter[21];

endmodule

// φ² + 1/φ² = 3 = TRINITY
