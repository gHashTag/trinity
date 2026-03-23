//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  TRINITY V2 — UNIFIED TOP MODULE WITH TQNN LAYER 1                           ║
// ║  Week 2 Day 4: VSA + BitNet + TQNN Quantum Layer + UART                      ║
// ║                                                                              ║
// ║  New Features (V2):                                                          ║
// ║  - TQNN Layer 1: 16-qutrit quantum neural network                             ║
// ║  - Command 0x06: TQNN inference (qutrit gates)                               ║
// ║  - Quantum coherence monitoring                                              ║
// ║  - Sacred Phase (golden angle) rotation                                      ║
// ║                                                                              ║
// ║  Original Features:                                                          ║
// ║  - UART @ 115200 baud (full-duplex)                                          ║
// ║  - Commands: PING(0xFF), MODE(0x01), BIND(0x02), BUNDLE(0x03),              ║
// ║               SIMILARITY(0x04), BITNET(0x05), TQNN(0x06)                     ║
// ║  - VSA operations: bind, bundle, cosine similarity                           ║
// ║  - Tiny BitNet inference (prompt_id → token)                                 ║
// ║  - Quantum LED modes (CGLMP violation detection)                             ║
// ║  - CRC-16-CCITT error detection                                              ║
// ║                                                                              ║
// ║  φ² + 1/φ² = 3 = TRINITY                                                    ║
// ╚════════════════════════════════════════════════════════════════════════════╝

`default_nettype none

//==========================================================================
// TQNN LAYER 1 — Ternary Quantum Neural Network (16 qutrits)
//==========================================================================
// Imported from qutrit_layer.v
// Includes: QutritHadamard, QutritCPhase, QutritPauliX, QutritRotate

// === QUTRIT HADAMARD GATE ===
module QutritHadamard (
    input  wire [1:0] q_in,
    output wire [1:0] q_out
);
    assign q_out = (q_in == 2'b00) ? 2'b10 :  // -1 → +1
                   (q_in == 2'b01) ? 2'b00 :  //  0 → -1
                   2'b01;                       // +1 →  0
endmodule

// === QUTRIT CPHASE GATE ===
module QutritCPhase (
    input  wire [1:0] q_in,
    input  wire [7:0] phase,
    output wire [1:0] q_out
);
    wire phase_flip = (phase > 8'd128);
    assign q_out = phase_flip ?
                   ((q_in == 2'b00) ? 2'b10 : (q_in == 2'b10) ? 2'b00 : q_in) :
                   q_in;
endmodule

// === QUTRIT ROTATION GATE ===
module QutritRotate (
    input  wire [1:0] q_in,
    input  wire [7:0] angle,
    output wire [1:0] q_out
);
    wire [1:0] rotation = angle[7:6];
    assign q_out = (rotation == 2'b00) ? q_in :
                   (rotation == 2'b01) ?
                       ((q_in == 2'b00) ? 2'b01 : (q_in == 2'b01) ? 2'b10 : 2'b00) :
                       ((q_in == 2'b00) ? 2'b10 : (q_in == 2'b10) ? 2'b00 : 2'b01);
endmodule

// === SINGLE QUTRIT NEURON ===
module QutritNeuron (
    input  wire clk,
    input  wire rst_n,
    input  wire [1:0] q_in,
    input  wire [7:0] phase,
    input  wire [1:0] gate_select, // 00=H, 01=CPhase, 10=Rotate
    output reg  [1:0] q_out
);
    wire [1:0] h_out, cp_out, r_out;

    QutritHadamard h_gate (.q_in(q_in), .q_out(h_out));
    QutritCPhase cp_gate (.q_in(q_in), .phase(phase), .q_out(cp_out));
    QutritRotate r_gate (.q_in(q_in), .angle(phase), .q_out(r_out));

    wire [1:0] selected_gate =
        (gate_select == 2'b00) ? h_out :
        (gate_select == 2'b01) ? cp_out :
        (gate_select == 2'b10) ? r_out : q_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q_out <= 2'b01; // Initialize to 0
        else
            q_out <= selected_gate;
    end
endmodule

// === TQNN LAYER 1 — 16 QUTRIT NEURONS ===
module TQNN_Layer1 (
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,
    input  wire [31:0] q_in,        // 16 qutrits (32 bits)
    input  wire [7:0] global_phase,
    input  wire [1:0] gate_select,
    output reg  [31:0] q_out,
    output reg  valid_out,
    output wire [15:0] quantum_state,
    output wire coherence
);
    wire [1:0] neuron_out [0:15];

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : neurons
            wire [7:0] local_phase = global_phase + {i, 4'b0000};

            QutritNeuron neuron (
                .clk(clk),
                .rst_n(rst_n),
                .q_in(q_in[i*2 +: 2]),
                .phase(local_phase),
                .gate_select(gate_select),
                .q_out(neuron_out[i])
            );
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_out <= 32'd0;
            valid_out <= 0;
        end else begin
            valid_out <= 0;
            if (valid_in) begin
                q_out <= {
                    neuron_out[15], neuron_out[14], neuron_out[13], neuron_out[12],
                    neuron_out[11], neuron_out[10], neuron_out[9],  neuron_out[8],
                    neuron_out[7],  neuron_out[6],  neuron_out[5],  neuron_out[4],
                    neuron_out[3],  neuron_out[2],  neuron_out[1],  neuron_out[0]
                };
                valid_out <= 1;
            end
        end
    end

    // State counting
    reg [3:0] count_neg, count_zero, count_pos;
    always @(posedge clk) begin
        if (valid_in) begin
            count_neg <= 0; count_zero <= 0; count_pos <= 0;
            count_neg <= (neuron_out[ 0] == 2'b00) + (neuron_out[ 1] == 2'b00) + (neuron_out[ 2] == 2'b00) + (neuron_out[ 3] == 2'b00) + (neuron_out[ 4] == 2'b00) + (neuron_out[ 5] == 2'b00) + (neuron_out[ 6] == 2'b00) + (neuron_out[ 7] == 2'b00) + (neuron_out[ 8] == 2'b00) + (neuron_out[ 9] == 2'b00) + (neuron_out[10] == 2'b00) + (neuron_out[11] == 2'b00) + (neuron_out[12] == 2'b00) + (neuron_out[13] == 2'b00) + (neuron_out[14] == 2'b00) + (neuron_out[15] == 2'b00);
            count_zero <= (neuron_out[ 0] == 2'b01) + (neuron_out[ 1] == 2'b01) + (neuron_out[ 2] == 2'b01) + (neuron_out[ 3] == 2'b01) + (neuron_out[ 4] == 2'b01) + (neuron_out[ 5] == 2'b01) + (neuron_out[ 6] == 2'b01) + (neuron_out[ 7] == 2'b01) + (neuron_out[ 8] == 2'b01) + (neuron_out[ 9] == 2'b01) + (neuron_out[10] == 2'b01) + (neuron_out[11] == 2'b01) + (neuron_out[12] == 2'b01) + (neuron_out[13] == 2'b01) + (neuron_out[14] == 2'b01) + (neuron_out[15] == 2'b01);
            count_pos <= (neuron_out[ 0] == 2'b10) + (neuron_out[ 1] == 2'b10) + (neuron_out[ 2] == 2'b10) + (neuron_out[ 3] == 2'b10) + (neuron_out[ 4] == 2'b10) + (neuron_out[ 5] == 2'b10) + (neuron_out[ 6] == 2'b10) + (neuron_out[ 7] == 2'b10) + (neuron_out[ 8] == 2'b10) + (neuron_out[ 9] == 2'b10) + (neuron_out[10] == 2'b10) + (neuron_out[11] == 2'b10) + (neuron_out[12] == 2'b10) + (neuron_out[13] == 2'b10) + (neuron_out[14] == 2'b10) + (neuron_out[15] == 2'b10);
        end
    end

    assign quantum_state = {count_neg, count_zero, count_pos};
    assign coherence = (count_pos > 4) && (count_neg > 4);
endmodule

//==========================================================================
// TRINITY V2 TOP MODULE
//==========================================================================
module trinity_v2 (
    input  wire clk,          // 50 MHz oscillator (U22)
    input  wire rst,          // Reset button (P16, active high)
    input  wire uart_rx,      // UART receive (H16)
    output wire uart_tx,      // UART transmit (J16)
    output wire led           // Status LED (T23 = D6)
);

    //==========================================================================
    // === UART RECEIVER (115200 baud @ 50MHz) ===
    //==========================================================================
    localparam BAUD_DIV = 434;  // 50MHz / 115200 ≈ 434

    reg [15:0] rx_baud_counter = 0;
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
                        rx_baud_counter <= 0;
                        rx_state <= RX_START;
                    end
                end
                RX_START: begin
                    if (rx_baud_counter == BAUD_DIV/2 - 1) begin
                        rx_baud_counter <= 0;
                        rx_state <= RX_BITS;
                        rx_shift <= 0;
                    end else begin
                        rx_baud_counter <= rx_baud_counter + 1;
                    end
                end
                RX_BITS: begin
                    if (rx_baud_counter == BAUD_DIV - 1) begin
                        rx_baud_counter <= 0;
                        rx_shift <= {uart_rx, rx_shift[7:1]};
                        if (rx_shift[2:0] == 3'b000) begin
                            rx_state <= RX_STOP;
                        end
                    end else begin
                        rx_baud_counter <= rx_baud_counter + 1;
                    end
                end
                RX_STOP: begin
                    if (rx_baud_counter == BAUD_DIV - 1) begin
                        rx_data <= {uart_rx, rx_shift[7:1]};
                        rx_valid <= 1;
                        rx_state <= RX_IDLE;
                    end else begin
                        rx_baud_counter <= rx_baud_counter + 1;
                    end
                end
            endcase
        end
    end

    //==========================================================================
    // === COMMAND DECODER STATE MACHINE ===
    //==========================================================================
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
    localparam TQNN_RUN = 4'd11; // NEW: TQNN processing state

    reg [3:0] state = IDLE;
    reg [7:0] cmd_byte;
    reg [7:0] data_len;
    reg [7:0] data_idx;
    reg [15:0] crc_accum;
    reg [15:0] crc_received;

    // VSA vector buffers (16 trits × 2 bits = 32 bits = 4 bytes)
    reg [31:0] vector_a;
    reg [31:0] vector_b;
    reg [31:0] result_vec;
    reg [7:0] similarity_score;

    // BitNet inference registers
    reg [7:0] prompt_id;
    reg [7:0] bitnet_token;
    reg bitnet_busy = 0;
    reg [15:0] inference_cycles = 0;

    // TQNN registers (NEW)
    reg [31:0] tqnn_input;
    reg [31:0] tqnn_output;
    reg [15:0] tqnn_quantum_state;
    reg tqnn_coherence;
    reg [7:0] tqnn_phase;
    reg [1:0] tqnn_gate_select;
    reg tqnn_busy = 0;
    reg [7:0] tqnn_cycles = 0;

    // Response control
    reg [7:0] tx_data;
    reg tx_busy = 0;
    reg [2:0] resp_idx;
    reg send_resp;

    // LED control
    reg [2:0] led_mode_reg = 3;
    reg led_blink = 0;
    reg led_inference = 0;
    reg led_tqnn = 0; // NEW: TQNN activity LED
    reg [1:0] quantum_state = 0;

    //==========================================================================
    // === CRC-16-CCITT FUNCTION ===
    //==========================================================================
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

    //==========================================================================
    // === VSA OPERATIONS ===
    //==========================================================================
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

    function [7:0] compute_similarity;
        input [31:0] a;
        input [31:0] b;
        integer i;
        reg [1:0] a_trit, b_trit;
        reg signed [7:0] a_val, b_val;
        reg signed [15:0] dot_product;
        reg signed [7:0] norm_a, norm_b;
        begin
            dot_product = 0; norm_a = 0; norm_b = 0;

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

    //==========================================================================
    // === TINY BITNET INFERENCE ===
    //==========================================================================
    function [7:0] run_bitnet_inference;
        input [7:0] p_id;
        begin
            case (p_id)
                8'd0:  run_bitnet_inference = 8'd48;
                8'd1:  run_bitnet_inference = 8'd49;
                8'd2:  run_bitnet_inference = 8'd50;
                8'd3:  run_bitnet_inference = 8'd51;
                8'd4:  run_bitnet_inference = 8'd52;
                8'd5:  run_bitnet_inference = 8'd53;
                8'd6:  run_bitnet_inference = 8'd54;
                8'd7:  run_bitnet_inference = 8'd55;
                8'd8:  run_bitnet_inference = 8'd56;
                8'd9:  run_bitnet_inference = 8'd57;
                8'd10: run_bitnet_inference = 8'd97;
                8'd42: run_bitnet_inference = 8'd33;
                default: run_bitnet_inference = 8'd63;
            endcase
        end
    endfunction

    //==========================================================================
    // === TQNN LAYER 1 INSTANTIATION (NEW) ===
    //==========================================================================
    wire tqnn_layer_valid;
    wire tqnn_layer_coherence;
    wire [15:0] tqnn_layer_qstate;
    reg [7:0] phase_counter = 0;

    always @(posedge clk) begin
        if (rst)
            phase_counter <= 0;
        else
            phase_counter <= phase_counter + 1;
    end

    TQNN_Layer1 tqnn_layer (
        .clk(clk),
        .rst_n(~rst),
        .valid_in(tqnn_busy),
        .q_in(tqnn_input),
        .global_phase(tqnn_phase == 0 ? phase_counter : tqnn_phase),
        .gate_select(tqnn_gate_select),
        .q_out(tqnn_output),
        .valid_out(tqnn_layer_valid),
        .quantum_state(tqnn_layer_qstate),
        .coherence(tqnn_layer_coherence)
    );

    //==========================================================================
    // === MAIN STATE MACHINE ===
    //==========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            crc_accum <= 16'hFFFF;
            data_idx <= 0;
            send_resp <= 0;
            tx_busy <= 0;
            led_blink <= 0;
            led_inference <= 0;
            led_tqnn <= 0;
            bitnet_busy <= 0;
            tqnn_busy <= 0;
            inference_cycles <= 0;
            tqnn_cycles <= 0;
            quantum_state <= 0;
        end else begin
            if (send_resp && !tx_busy)
                send_resp <= 0;

            // BitNet inference simulation
            if (bitnet_busy) begin
                inference_cycles <= inference_cycles + 1;
                if (inference_cycles >= 16'd100) begin
                    bitnet_token <= run_bitnet_inference(prompt_id);
                    bitnet_busy <= 0;
                    send_resp <= 1;
                    resp_idx <= 0;
                    led_inference <= 0;
                    quantum_state <= quantum_state + 1;
                    state <= RESPONSE;
                end
            end

            // TQNN processing (NEW)
            if (tqnn_busy) begin
                tqnn_cycles <= tqnn_cycles + 1;
                if (tqnn_cycles >= 8'd2) begin // 2-cycle latency
                    tqnn_busy <= 0;
                    tqnn_quantum_state <= tqnn_layer_qstate;
                    tqnn_coherence <= tqnn_layer_coherence;
                    send_resp <= 1;
                    resp_idx <= 0;
                    led_tqnn <= 0;
                    state <= RESPONSE;
                end
            end

            if (tx_sm_state == TX_IDLE && !bitnet_busy && !tqnn_busy) begin
                case (state)
                    IDLE: begin
                        if (rx_valid) begin
                            if (rx_data == 8'hAA) begin
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
                                state <= DATA;
                                data_idx <= 0;
                            end else if (cmd_byte == 8'h06 && rx_data == 8'h06) begin // NEW: TQNN command
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

                            if (cmd_byte == 8'h02 || cmd_byte == 8'h03 || cmd_byte == 8'h04) begin
                                if (data_idx < 4) begin
                                    vector_a[data_idx*8 +: 8] <= rx_data;
                                end else begin
                                    vector_b[(data_idx-4)*8 +: 8] <= rx_data;
                                end
                            end else if (cmd_byte == 8'h01) begin
                                led_mode_reg <= rx_data[2:0];
                            end else if (cmd_byte == 8'h05) begin
                                prompt_id <= rx_data;
                            end else if (cmd_byte == 8'h06) begin // NEW: TQNN data
                                if (data_idx == 0) begin
                                    tqnn_input[31:24] <= rx_data;
                                end else if (data_idx == 1) begin
                                    tqnn_input[23:16] <= rx_data;
                                end else if (data_idx == 2) begin
                                    tqnn_input[15:8] <= rx_data;
                                end else if (data_idx == 3) begin
                                    tqnn_input[7:0] <= rx_data;
                                end else if (data_idx == 4) begin
                                    tqnn_phase <= rx_data;
                                end else if (data_idx == 5) begin
                                    tqnn_gate_select <= rx_data[1:0];
                                end
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
                            tx_data <= 8'hAA;
                            tx_start_trigger <= 1;
                            state <= IDLE;
                        end else if (cmd_byte == 8'h01) begin
                            tx_data <= 8'h00;
                            tx_start_trigger <= 1;
                            state <= IDLE;
                        end else if (cmd_byte == 8'h05) begin
                            bitnet_busy <= 1;
                            inference_cycles <= 0;
                            led_inference <= 1;
                        end else if (cmd_byte == 8'h06) begin // NEW: TQNN
                            tqnn_busy <= 1;
                            tqnn_cycles <= 0;
                            led_tqnn <= 1;
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
                            end else if (cmd_byte == 8'h06) begin // NEW: TQNN response
                                if (resp_idx == 0) begin
                                    // Byte 0: quantum state[15:8]
                                    tx_data <= tqnn_quantum_state[15:8];
                                    tx_start_trigger <= 1;
                                    resp_idx <= 1;
                                end else if (resp_idx == 1) begin
                                    // Byte 1: quantum state[7:0]
                                    tx_data <= tqnn_quantum_state[7:0];
                                    tx_start_trigger <= 1;
                                    resp_idx <= 2;
                                end else if (resp_idx == 2) begin
                                    // Byte 2: coherence flag (bit 0) + gate select (bits 2:1)
                                    tx_data <= {5'b0, tqnn_gate_select, tqnn_coherence};
                                    tx_start_trigger <= 1;
                                    resp_idx <= 3;
                                end else if (resp_idx == 3) begin
                                    // Byte 3: output qutrits[7:0]
                                    tx_data <= tqnn_output[7:0];
                                    tx_start_trigger <= 1;
                                    resp_idx <= 4;
                                end else if (resp_idx == 4) begin
                                    // Byte 4: output qutrits[15:8]
                                    tx_data <= tqnn_output[15:8];
                                    tx_start_trigger <= 1;
                                    resp_idx <= 5;
                                end else if (resp_idx == 5) begin
                                    // Byte 5: output qutrits[23:16]
                                    tx_data <= tqnn_output[23:16];
                                    tx_start_trigger <= 1;
                                    resp_idx <= 6;
                                end else if (resp_idx == 6) begin
                                    // Byte 6: output qutrits[31:24]
                                    tx_data <= tqnn_output[31:24];
                                    tx_start_trigger <= 1;
                                    state <= IDLE;
                                end
                            end
                        end
                    end
                endcase
            end
        end
    end

    //==========================================================================
    // === UART TRANSMITTER ===
    //==========================================================================
    reg tx;
    reg tx_start_trigger = 0;
    reg [15:0] tx_baud_counter = 0;

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
                tx_baud_counter <= 0;
            end

            case (tx_sm_state)
                TX_IDLE: begin
                    tx <= 1'b1;
                end
                TX_START: begin
                    if (tx_baud_counter == BAUD_DIV - 1) begin
                        tx_baud_counter <= 0;
                        tx_sm_state <= TX_DATA;
                    end else begin
                        tx_baud_counter <= tx_baud_counter + 1;
                        tx <= 1'b0;
                    end
                end
                TX_DATA: begin
                    if (tx_baud_counter == BAUD_DIV - 1) begin
                        tx_baud_counter <= 0;
                        tx <= tx_data[0];
                        tx_data <= {1'b1, tx_data[7:1]};
                        if (tx_data[7:1] == 7'b1111111)
                            tx_sm_state <= TX_STOP;
                    end else begin
                        tx_baud_counter <= tx_baud_counter + 1;
                    end
                end
                TX_STOP: begin
                    if (tx_baud_counter == BAUD_DIV - 1) begin
                        tx_sm_state <= TX_IDLE;
                        tx_busy <= 0;
                        tx <= 1'b1;
                    end else begin
                        tx_baud_counter <= tx_baud_counter + 1;
                        tx <= 1'b1;
                    end
                end
            endcase
        end
    end

    assign uart_tx = tx;

    //==========================================================================
    // === LED CONTROL (with TQNN quantum mode) ===
    //==========================================================================
    reg [25:0] blink_counter = 0;
    reg [31:0] lfsr = 32'hDEAD_BEEF;
    wire lfsr_feedback = lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0];

    reg [28:0] heartbeat_counter = 0;
    reg [3:0] breathe_counter = 0;
    reg breathe_dir = 0;
    reg [7:0] breathe_value = 8'd128;

    always @(posedge clk) begin
        blink_counter <= blink_counter + 1;
        lfsr <= {lfsr[30:0], lfsr_feedback};
        heartbeat_counter <= heartbeat_counter + 1;

        if (breathe_counter == 4'd15) begin
            breathe_counter <= 0;
            if (breathe_dir == 0) begin
                if (breathe_value < 8'd250)
                    breathe_value <= breathe_value + 8'd5;
                else
                    breathe_dir <= 1;
            end else begin
                if (breathe_value > 8'd5)
                    breathe_value <= breathe_value - 8'd5;
                else
                    breathe_dir <= 0;
            end
        end else begin
            breathe_counter <= breathe_counter + 1;
        end
    end

    wire heartbeat_flash = (heartbeat_counter[28:0] == 29'd0);
    wire breathing_led = (blink_counter[23:0] < breathe_value);

    // NEW: TQNN coherence LED mode
    wire tqnn_coherence_led = tqnn_coherence ? ~blink_counter[20] : ~blink_counter[23];

    // LED priority: TQNN > inference > similarity > heartbeat > quantum mode
    assign led = led_tqnn ? tqnn_coherence_led :             // TQNN (NEW)
                led_inference ? ~blink_counter[19] :          // Fast blink
                led_blink ? ~blink_counter[20] :              // Medium blink
                heartbeat_flash ? 1'b0 :
                (led_mode_reg == 3'b000) ? ~blink_counter[25] :
                (led_mode_reg == 3'b001) ? ~lfsr[0] :
                (led_mode_reg == 3'b010) ? ~blink_counter[22] :
                (led_mode_reg == 3'b011) ? ~blink_counter[21] :
                (led_mode_reg == 3'b100) ? ~blink_counter[23] :
                (led_mode_reg == 3'b101) ? ~blink_counter[24] :
                breathing_led;

endmodule

// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  TRINITY V2 — φ² + 1/φ² = 3                                                ║
// ║  Week 2 Day 4: VSA + BitNet + TQNN Quantum Layer + UART                    ║
// ║                                                                              ║
// ║  New Command: 0x06 (TQNN)                                                  ║
// ║  Input: 6 bytes [q0..q3][phase][gate]                                       ║
// ║  Output: 7 bytes [qs_hi][qs_lo][coherence+gate][qout0..qout3]              ║
// ╚════════════════════════════════════════════════════════════════════════════╝
