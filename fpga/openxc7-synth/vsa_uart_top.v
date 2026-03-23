//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// VSA FPGA Accelerator with UART Interface
// Week 3: Unified VSA operations with command protocol
//
// Commands (sent via UART):
//   0x01 - BIND: result = a * b
//   0x02 - BUNDLE2: result = majority(a, b)
//   0x03 - SIMILARITY: result = dot(a, b)
//   0xFF - PING: respond with PONG
//
// Protocol:
//   [CMD][LEN_H][LEN_L][DATA...][CRC]

`default_nettype none

module vsa_uart_top (
    input  wire clk,          // 50 MHz (U22)
    input  wire rst,          // Reset button (active high)
    input  wire uart_rx,      // UART receive
    output wire uart_tx,      // UART transmit
    output wire led           // Status LED (T23)
);

    // ═══════════════════════════════════════════════════════════════════════
    // CLOCK GENERATION
    // ═══════════════════════════════════════════════════════════════════════
    // 50 MHz input, no PLL needed (runs directly)

    // ═══════════════════════════════════════════════════════════════════════
    // UART TRANSMITTER
    // ═══════════════════════════════════════════════════════════════════════
    parameter CLK_FREQ = 50_000_000;
    parameter BAUD = 115200;

    reg [7:0] tx_data;
    reg tx_start;
    wire tx_busy;
    wire uart_tx_wire;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) tx (
        .clk(clk),
        .rst(rst),
        .data(tx_data),
        .start(tx_start),
        .uart_tx(uart_tx_wire),
        .busy(tx_busy)
    );

    // ═══════════════════════════════════════════════════════════════════════
    // UART RECEIVER
    // ═══════════════════════════════════════════════════════════════════════
    wire [7:0] rx_data;
    wire rx_data_valid;
    wire framing_error;

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) rx (
        .clk(clk),
        .rst(rst),
        .uart_rx(uart_rx),
        .data(rx_data),
        .data_valid(rx_data_valid),
        .framing_error(framing_error)
    );

    // ═══════════════════════════════════════════════════════════════════════
    // COMMAND DECODER
    // ═══════════════════════════════════════════════════════════════════════

    // Command states
    localparam IDLE = 0;
    localparam CMD = 1;
    localparam LEN_H = 2;
    localparam LEN_L = 3;
    localparam DATA = 4;
    localparam EXECUTE = 5;
    localparam RESPONSE = 6;

    reg [2:0] state;
    reg [7:0] cmd;
    reg [15:0] data_len;
    reg [511:0] vector_a;
    reg [511:0] vector_b;
    reg [7:0] data_idx;

    // VSA operation results
    wire bind_valid;
    wire [511:0] bind_result;
    wire bundle_valid;
    wire [511:0] bundle_result;
    wire sim_valid;
    wire signed [18:0] dot_product;

    // Instantiate VSA modules
    vsa_bind_256 bind_inst (
        .clk(clk),
        .rst(rst),
        .valid_in(state == EXECUTE && cmd == 8'h01),
        .a(vector_a),
        .b(vector_b),
        .valid_out(bind_valid),
        .result(bind_result)
    );

    vsa_bundle_256 bundle_inst (
        .clk(clk),
        .rst(rst),
        .valid_in(state == EXECUTE && cmd == 8'h02),
        .a(vector_a),
        .b(vector_b),
        .valid_out(bundle_valid),
        .result(bundle_result)
    );

    vsa_similarity_256 sim_inst (
        .clk(clk),
        .rst(rst),
        .valid_in(state == EXECUTE && cmd == 8'h03),
        .a(vector_a),
        .b(vector_b),
        .valid_out(sim_valid),
        .dot_product(dot_product)
    );

    // State machine
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            cmd <= 0;
            data_len <= 0;
            vector_a <= 0;
            vector_b <= 0;
            data_idx <= 0;
            tx_start <= 0;
        end else begin
            tx_start <= 0;  // Default: no TX

            case (state)
                IDLE: begin
                    if (rx_data_valid) begin
                        cmd <= rx_data;
                        state <= LEN_H;
                    end
                end

                LEN_H: begin
                    if (rx_data_valid) begin
                        data_len[15:8] <= rx_data;
                        state <= LEN_L;
                    end
                end

                LEN_L: begin
                    if (rx_data_valid) begin
                        data_len[7:0] <= rx_data;
                        data_idx <= 0;
                        if (rx_data == 0)
                            state <= EXECUTE;
                        else
                            state <= DATA;
                    end
                end

                DATA: begin
                    if (rx_data_valid) begin
                        // Pack bytes into 512-bit vector
                        if (data_idx < 64) begin
                            vector_a[data_idx*8 +: 8] <= rx_data;
                        end else begin
                            vector_b[(data_idx-64)*8 +: 8] <= rx_data;
                        end

                        data_idx <= data_idx + 1;
                        if (data_idx >= data_len - 1) begin
                            state <= EXECUTE;
                        end
                    end
                end

                EXECUTE: begin
                    // Wait for operation to complete
                    if ((cmd == 8'h01 && bind_valid) ||
                        (cmd == 8'h02 && bundle_valid) ||
                        (cmd == 8'h03 && sim_valid) ||
                        (cmd == 8'hFF)) begin
                        state <= RESPONSE;
                        data_idx <= 0;
                    end
                end

                RESPONSE: begin
                    // Send response via UART
                    if (!tx_busy) begin
                        case (cmd)
                            8'h01: begin  // BIND
                                // Send 64 bytes
                                if (data_idx < 64) begin
                                    tx_data <= bind_result[data_idx*8 +: 8];
                                    tx_start <= 1;
                                    data_idx <= data_idx + 1;
                                end else begin
                                    state <= IDLE;
                                end
                            end
                            8'h02: begin  // BUNDLE
                                if (data_idx < 64) begin
                                    tx_data <= bundle_result[data_idx*8 +: 8];
                                    tx_start <= 1;
                                    data_idx <= data_idx + 1;
                                end else begin
                                    state <= IDLE;
                                end
                            end
                            8'h03: begin  // SIMILARITY
                                if (data_idx == 0) begin
                                    // Send status byte
                                    tx_data <= 8'h00;  // OK
                                    tx_start <= 1;
                                    data_idx <= 1;
                                end else if (data_idx == 1) begin
                                    // Send dot product LSB
                                    tx_data <= dot_product[7:0];
                                    tx_start <= 1;
                                    data_idx <= 2;
                                end else if (data_idx == 2) begin
                                    // Send dot product MSB
                                    tx_data <= {7'h0, dot_product[10:8]};
                                    tx_start <= 1;
                                    data_idx <= 3;
                                end else begin
                                    state <= IDLE;
                                end
                            end
                            8'hFF: begin  // PING
                                tx_data <= 8'hFF;  // PONG
                                tx_start <= 1;
                                state <= IDLE;
                            end
                            default: state <= IDLE;
                        endcase
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // ═══════════════════════════════════════════════════════════════════════
    // LED STATUS INDICATOR
    // ═══════════════════════════════════════════════════════════════════════
    reg [23:0] blink_counter;
    reg led_reg;

    always @(posedge clk) begin
        if (rst) begin
            blink_counter <= 0;
            led_reg <= 1;
        end else begin
            blink_counter <= blink_counter + 1;

            // Blink based on state
            case (state)
                IDLE: begin
                    // Slow blink: idle
                    if (blink_counter[23] == 1) led_reg <= ~led_reg;
                end
                EXECUTE: begin
                    // Fast blink: processing
                    if (blink_counter[20] == 1) led_reg <= ~led_reg;
                end
                default: begin
                    // Medium blink: data transfer
                    if (blink_counter[22] == 1) led_reg <= ~led_reg;
                end
            endcase
        end
    end

    assign led = ~led_reg;  // Active-low
    assign uart_tx = uart_tx_wire;

endmodule

// ═════════════════════════════════════════════════════════════════════════════
// UART Transmitter (from fpga/rtl/uart_tx.v)
// ═════════════════════════════════════════════════════════════════════════════

module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD = 115200
)(
    input wire clk,
    input wire rst,
    input wire [7:0] data,
    input wire start,
    output reg uart_tx,
    output reg busy
);

    localparam DIVISOR = CLK_FREQ / BAUD;
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [31:0] counter;
    reg [1:0] state;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;

    always @(posedge clk) begin
        counter <= counter + 1;
        if (counter >= DIVISOR - 1) begin
            counter <= 0;

            case (state)
                IDLE: begin
                    uart_tx <= 1;
                    if (start && !busy) begin
                        shift_reg <= data;
                        bit_idx <= 0;
                        state <= START;
                        busy <= 1;
                    end else begin
                        busy <= 0;
                    end
                end

                START: begin
                    uart_tx <= 0;
                    state <= DATA;
                end

                DATA: begin
                    uart_tx <= shift_reg[bit_idx];
                    bit_idx <= bit_idx + 1;
                    if (bit_idx == 7)
                        state <= STOP;
                end

                STOP: begin
                    uart_tx <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

// ═════════════════════════════════════════════════════════════════════════════
// UART Receiver
// ═════════════════════════════════════════════════════════════════════════════

module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD = 115200
)(
    input wire clk,
    input wire rst,
    input wire uart_rx,
    output reg [7:0] data,
    output reg data_valid,
    output reg framing_error
);

    localparam DIVISOR = CLK_FREQ / BAUD;
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [31:0] counter;
    reg [1:0] state;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;
    reg [2:0] rx_sync;

    always @(posedge clk) begin
        rx_sync <= {rx_sync[1:0], uart_rx};
    end

    always @(posedge clk) begin
        data_valid <= 0;
        framing_error <= 0;
        counter <= counter + 1;

        if (counter >= DIVISOR - 1) begin
            counter <= 0;

            case (state)
                IDLE: begin
                    if (rx_sync[1] == 0) begin
                        state <= START;
                        counter <= DIVISOR / 2;
                    end
                end

                START: begin
                    if (rx_sync[1] == 0) begin
                        state <= DATA;
                    end
                end

                DATA: begin
                    shift_reg[bit_idx] <= rx_sync[1];
                    bit_idx <= bit_idx + 1;
                    if (bit_idx == 7)
                        state <= STOP;
                end

                STOP: begin
                    data <= shift_reg;
                    data_valid <= 1;
                    if (rx_sync[1] == 0)
                        framing_error <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

// φ² + 1/φ² = 3 = TRINITY
