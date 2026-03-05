// VSA SIMILARITY TOP — Bind + Bundle + Similarity via UART
// Day 4: Added SIMILARITY command with cosine score
//
// Features:
// - UART receiver at 115200 baud
// - BIND command (0x02): bind two 16-trit vectors
// - BUNDLE command (0x03): bundle two 16-trit vectors
// - SIMILARITY command (0x04): cosine similarity score (0-255)
// - MODE command (0x01) from Day 2 preserved
// - Enhanced protocol with sync byte (0xAA)
//
// Protocol:
//   [0xAA][CMD][LEN_H][LEN_L][DATA...][CRC_L][CRC_H]
//   BIND: 0x02 with 8 bytes data (4+4 for two 16-trit vectors)
//   BUNDLE: 0x03 with 8 bytes data
//   SIMILARITY: 0x04 with 8 bytes data → returns 1 byte score (0-255)

`default_nettype none

module vsa_sim_top (
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
    reg [31:0] vector_a;
    reg [31:0] vector_b;
    reg [31:0] result_vec;

    // Similarity score (cosine similarity × 255)
    reg [7:0] similarity_score;

    // Response data
    reg [7:0] tx_data;
    reg [15:0] tx_counter = 0;
    reg tx_busy = 0;
    reg [2:0] resp_idx;
    reg send_resp;

    // LED mode
    reg [1:0] led_mode_reg = 2;
    reg led_blink = 0;

    // === CRC-16-CCITT FUNCTION ===
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
            led_blink <= 0;
        end else begin
            if (send_resp && !tx_busy)
                send_resp <= 0;

            if (tx_sm_state == TX_IDLE) begin
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

                            if (cmd_byte == 8'hFF && rx_data == 8'h00) begin
                                state <= CRC_L;
                            end else if (cmd_byte == 8'h01 && rx_data == 8'h00) begin
                                state <= DATA;
                                data_idx <= 0;
                            end else if ((cmd_byte == 8'h02 || cmd_byte == 8'h03 || cmd_byte == 8'h04) && rx_data == 8'h08) begin
                                state <= DATA;
                                data_idx <= 0;
                            end else begin
                                state <= IDLE;
                            end
                        end
                    end

                    LEN_L: begin
                        state <= IDLE;
                    end

                    DATA: begin
                        if (rx_valid) begin
                            crc_accum <= crc16_byte(rx_data, crc_accum);

                            if (data_idx < 4) begin
                                vector_a[data_idx*8 +: 8] <= rx_data;
                            end else if (data_idx < 8) begin
                                vector_b[(data_idx-4)*8 +: 8] <= rx_data;
                            end else if (cmd_byte == 8'h01) begin
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
                        if (cmd_byte == 8'hFF) begin
                            tx_data <= 8'hAA;  // PONG
                            tx_start_trigger <= 1;
                            state <= IDLE;
                        end else if (cmd_byte == 8'h01) begin
                            tx_data <= 8'h00;  // OK
                            tx_start_trigger <= 1;
                            state <= IDLE;
                        end else begin
                            state <= EXECUTE;
                        end
                    end

                    EXECUTE: begin
                        if (cmd_byte == 8'h02) begin
                            result_vec <= bind_vectors(vector_a, vector_b);
                            send_resp <= 1;
                            resp_idx <= 0;
                            state <= RESPONSE;
                        end else if (cmd_byte == 8'h03) begin
                            result_vec <= bundle_vectors(vector_a, vector_b);
                            send_resp <= 1;
                            resp_idx <= 0;
                            state <= RESPONSE;
                        end else if (cmd_byte == 8'h04) begin
                            // Similarity: compute cosine score
                            similarity_score <= compute_similarity(vector_a, vector_b);
                            send_resp <= 1;
                            resp_idx <= 0;
                            led_blink <= 1;  // Blink LED during similarity
                            state <= RESPONSE;
                        end
                    end

                    RESPONSE: begin
                        if (send_resp && !tx_busy) begin
                            if (cmd_byte == 8'h02 || cmd_byte == 8'h03) begin
                                // BIND/BUNDLE: return 4 bytes
                                if (resp_idx < 4) begin
                                    tx_data <= result_vec[resp_idx*8 +: 8];
                                    tx_start_trigger <= 1;
                                    resp_idx <= resp_idx + 1;
                                end else begin
                                    state <= IDLE;
                                end
                            end else if (cmd_byte == 8'h04) begin
                                // SIMILARITY: return 1 byte score
                                tx_data <= similarity_score;
                                tx_start_trigger <= 1;
                                state <= IDLE;
                            end
                        end
                    end
                endcase
            end
        end
    end

    // === BIND FUNCTION ===
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

                if (a_trit == 2'b00 || b_trit == 2'b00)
                    result_trit = 2'b00;
                else if (a_trit == b_trit)
                    result_trit = 2'b01;
                else
                    result_trit = 2'b10;

                bind_vectors[i*2 +: 2] = result_trit;
            end
        end
    endfunction

    // === BUNDLE FUNCTION ===
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

                if (a_trit == 2'b10 && b_trit == 2'b10)
                    result_trit = 2'b10;
                else if (a_trit == 2'b01 && b_trit == 2'b01)
                    result_trit = 2'b01;
                else if (a_trit == 2'b00)
                    result_trit = b_trit;
                else if (b_trit == 2'b00)
                    result_trit = a_trit;
                else
                    result_trit = 2'b00;

                bundle_vectors[i*2 +: 2] = result_trit;
            end
        end
    endfunction

    // === SIMILARITY FUNCTION ===
    // Compute cosine similarity for ternary vectors
    // Returns 0-255 (scaled cosine similarity)
    function [7:0] compute_similarity;
        input [31:0] a;
        input [31:0] b;
        integer i;
        reg [1:0] a_trit, b_trit;
        reg signed [7:0] a_val, b_val;
        reg signed [15:0] dot_product;
        reg signed [7:0] norm_a, norm_b;
        begin
            dot_product = 0;
            norm_a = 0;
            norm_b = 0;

            for (i = 0; i < 16; i = i + 1) begin
                a_trit = a[i*2 +: 2];
                b_trit = b[i*2 +: 2];

                // Convert trit to value: 00→0, 01→+1, 10→-1
                a_val = (a_trit == 2'b01) ? 8'sd01 : (a_trit == 2'b10) ? 8'sd81 : 8'sd00;
                b_val = (b_trit == 2'b01) ? 8'sd01 : (b_trit == 2'b10) ? 8'sd81 : 8'sd00;

                dot_product = dot_product + (a_val * b_val);
                norm_a = norm_a + (a_val * a_val);
                norm_b = norm_b + (b_val * b_val);
            end

            // Cosine similarity = dot / (sqrt(norm_a) * sqrt(norm_b))
            // Simplified: if norms equal, just scale dot product
            // Return 0-255 where 255 = identical, 0 = orthogonal
            if (norm_a == 0 || norm_b == 0)
                compute_similarity = 8'd0;
            else if (dot_product >= 0)
                compute_similarity = (dot_product * 8'd255) / (norm_a + norm_b);
            else
                compute_similarity = 8'd0;
        end
    endfunction

    // === UART TX ===
    reg tx;
    reg tx_start_trigger = 0;

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
                TX_START: begin
                    if (tx_counter == BAUD_DIV - 1) begin
                        tx_counter <= 0;
                        tx_sm_state <= TX_DATA;
                    end else begin
                        tx_counter <= tx_counter + 1;
                        tx <= 1'b0;
                    end
                end
                TX_DATA: begin
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
                TX_STOP: begin
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

    // === LED CONTROL ===
    reg [25:0] blink_counter = 0;
    reg [31:0] lfsr = 32'hDEAD_BEEF;
    wire lfsr_feedback = lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0];

    always @(posedge clk) begin
        blink_counter <= blink_counter + 1;
        lfsr <= {lfsr[30:0], lfsr_feedback};
    end

    // LED shows mode, or blinks during similarity computation
    assign led = led_blink ? ~blink_counter[20] :
                (led_mode_reg == 2'b00) ? ~blink_counter[25] :
                (led_mode_reg == 2'b01) ? ~lfsr[0] :
                (led_mode_reg == 2'b10) ? ~blink_counter[22] :
                ~blink_counter[21];

endmodule

// φ² + 1/φ² = 3 = TRINITY
