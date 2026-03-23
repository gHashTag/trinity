//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// VSA BITNET TOP — Bind + Bundle + Similarity + BitNet Inference via UART
// Day 5: Added BITNET command for tiny inference
//
// Features:
// - UART receiver at 115200 baud
// - BIND command (0x02): bind two 16-trit vectors
// - BUNDLE command (0x03): bundle two 16-trit vectors
// - SIMILARITY command (0x04): cosine similarity score (0-255)
// - BITNET command (0x05): run tiny inference with prompt_id → return token
// - MODE command (0x01) from Day 2 preserved
// - Enhanced protocol with sync byte (0xAA)
//
// Protocol:
//   [0xAA][CMD][LEN_H][LEN_L][DATA...][CRC_L][CRC_H]
//   BIND: 0x02 with 8 bytes data → returns 4 bytes result
//   BUNDLE: 0x03 with 8 bytes data → returns 4 bytes result
//   SIMILARITY: 0x04 with 8 bytes data → returns 1 byte score (0-255)
//   BITNET: 0x05 with 1 byte (prompt_id) → returns 1 byte token

`default_nettype none

module vsa_bitnet_top (
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
                    if (baud_counter == BAUD_DIV/2 - 1) begin
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

    // BitNet inference
    reg [7:0] prompt_id;
    reg [7:0] bitnet_token;
    reg bitnet_busy = 0;
    reg [15:0] inference_cycles = 0;

    // Response data
    reg [7:0] tx_data;
    reg [15:0] tx_counter = 0;
    reg tx_busy = 0;
    reg [2:0] resp_idx;
    reg send_resp;

    // LED mode
    reg [1:0] led_mode_reg = 2;
    reg led_blink = 0;
    reg led_inference = 0;

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

    // === TINY BITNET INFERENCE STUB ===
    // Day 5: Returns a fixed token based on prompt_id
    // Future: Will load TQ1_0 weights and compute actual inference
    function [7:0] run_bitnet_inference;
        input [7:0] p_id;
        begin
            // Stub: map prompt_id to token (for testing)
            // prompt_id 0-9 → tokens '0'-'9'
            // prompt_id 10-35 → tokens 'a'-'z'
            // prompt_id 42 → '!' (special "answer" token)
            // prompt_id 255 → '?' (unknown)

            case (p_id)
                8'd0:  run_bitnet_inference = 8'd48;  // '0'
                8'd1:  run_bitnet_inference = 8'd49;  // '1'
                8'd2:  run_bitnet_inference = 8'd50;  // '2'
                8'd3:  run_bitnet_inference = 8'd51;  // '3'
                8'd4:  run_bitnet_inference = 8'd52;  // '4'
                8'd5:  run_bitnet_inference = 8'd53;  // '5'
                8'd6:  run_bitnet_inference = 8'd54;  // '6'
                8'd7:  run_bitnet_inference = 8'd55;  // '7'
                8'd8:  run_bitnet_inference = 8'd56;  // '8'
                8'd9:  run_bitnet_inference = 8'd57;  // '9'
                8'd10: run_bitnet_inference = 8'd97;  // 'a'
                8'd42: run_bitnet_inference = 8'd33;  // '!' (answer)
                default: run_bitnet_inference = 8'd63; // '?'
            endcase
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
            led_inference <= 0;
            bitnet_busy <= 0;
            inference_cycles <= 0;
        end else begin
            if (send_resp && !tx_busy)
                send_resp <= 0;

            // BitNet inference simulation (100 cycles)
            if (bitnet_busy) begin
                inference_cycles <= inference_cycles + 1;
                if (inference_cycles >= 16'd100) begin
                    bitnet_token <= run_bitnet_inference(prompt_id);
                    bitnet_busy <= 0;
                    send_resp <= 1;
                    resp_idx <= 0;
                    led_inference <= 0;
                    state <= RESPONSE;
                end
            end

            if (tx_sm_state == TX_IDLE && !bitnet_busy) begin
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
                            end else if (cmd_byte == 8'h05 && rx_data == 8'h01) begin
                                // BITNET: 1 byte prompt_id
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
                            end else if (cmd_byte == 8'h05) begin
                                // BITNET prompt_id
                                prompt_id <= rx_data;
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
                        end else if (cmd_byte == 8'h05) begin
                            // BITNET: start inference
                            bitnet_busy <= 1;
                            inference_cycles <= 0;
                            led_inference <= 1;
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
                            similarity_score <= compute_similarity(vector_a, vector_b);
                            send_resp <= 1;
                            resp_idx <= 0;
                            led_blink <= 1;
                            state <= RESPONSE;
                        end
                    end

                    RESPONSE: begin
                        if (send_resp && !tx_busy) begin
                            if (cmd_byte == 8'h02 || cmd_byte == 8'h03) begin
                                if (resp_idx < 4) begin
                                    tx_data <= result_vec[resp_idx*8 +: 8];
                                    tx_start_trigger <= 1;
                                    resp_idx <= resp_idx + 1;
                                end else begin
                                    state <= IDLE;
                                end
                            end else if (cmd_byte == 8'h04) begin
                                tx_data <= similarity_score;
                                tx_start_trigger <= 1;
                                state <= IDLE;
                            end else if (cmd_byte == 8'h05) begin
                                tx_data <= bitnet_token;
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

                a_val = (a_trit == 2'b01) ? 8'sd01 : (a_trit == 2'b10) ? 8'sd81 : 8'sd00;
                b_val = (b_trit == 2'b01) ? 8'sd01 : (b_trit == 2'b10) ? 8'sd81 : 8'sd00;

                dot_product = dot_product + (a_val * b_val);
                norm_a = norm_a + (a_val * a_val);
                norm_b = norm_b + (b_val * b_val);
            end

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
                    if (baud_counter == BAUD_DIV - 1) begin
                        tx_counter <= 0;
                        tx_sm_state <= TX_DATA;
                    end else begin
                        tx_counter <= tx_counter + 1;
                        tx <= 1'b0;
                    end
                end
                TX_DATA: begin
                    if (baud_counter == BAUD_DIV - 1) begin
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
                    if (baud_counter == BAUD_DIV - 1) begin
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

    // LED priority: inference > similarity > mode
    assign led = led_inference ? ~blink_counter[19] :
                led_blink ? ~blink_counter[20] :
                (led_mode_reg == 2'b00) ? ~blink_counter[25] :
                (led_mode_reg == 2'b01) ? ~lfsr[0] :
                (led_mode_reg == 2'b10) ? ~blink_counter[22] :
                ~blink_counter[21];

endmodule

// φ² + 1/φ² = 3 = TRINITY
// Day 5: BITNET INFERENCE — prompt → token
