// VSA QUANTUM TOP — UART Control + Quantum Modes
// Week 5: Enhanced UART receiver with mode switching
//
// Features:
// - UART receiver at 115200 baud
// - 4 LED modes: wait, slow, fast, chaotic
// - Quantum mode control via UART
// - Backward compatible with VSA commands

`default_nettype none

module vsa_quantum_top (
    input  wire clk,          // 50 MHz (U22)
    input  wire rst,          // Reset (active high)
    input  wire uart_rx,      // UART receive (H16)
    output wire uart_tx,      // UART transmit (J16)
    output wire led           // Status LED (T23)
);

    // === UART RECEIVER (115200 baud @ 50MHz) ===
    // Baud timer: 50MHz / 115200 = 434 cycles per bit
    localparam BAUD_DIV = 434;

    reg [15:0] baud_counter = 0;
    reg [2:0] rx_state = 0;
    reg [7:0] rx_shift = 0;
    reg [7:0] rx_data = 0;
    reg rx_valid = 0;
    wire rx_busy = (rx_state != 0);

    // UART RX state machine
    localparam RX_IDLE = 0;
    localparam RX_START = 1;
    localparam RX_BITS = 2;
    localparam RX_STOP = 3;

    always @(posedge clk) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_valid <= 0;
        end else begin
            rx_valid <= 0;  // Pulse

            case (rx_state)
                RX_IDLE: begin
                    if (!uart_rx) begin  // Start bit
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
                        if (rx_shift[2:0] == 3'b000) begin  // 8 bits received
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

    // === COMMAND DECODER ===
    // Commands:
    //   0xFF - PING (respond with 0xAA PONG)
    //   0x01 XX - MODE (XX = 00=separable, 01=violation, 10=zero, 11=negative)

    // Command types for parameter receiver
    localparam CMD_NONE = 3'd0;
    localparam CMD_PING = 3'd1;
    localparam CMD_MODE = 3'd2;

    reg [2:0] cmd_type = CMD_NONE;
    reg [1:0] led_mode_reg = 2;    // Default: chaotic (violation)
    reg uart_received = 0;
    reg send_pong = 0;            // Trigger PONG response
    reg send_ok = 0;              // Trigger OK response

    always @(posedge clk) begin
        if (rst) begin
            led_mode_reg <= 2;
            uart_received <= 0;
            send_pong <= 0;
            send_ok <= 0;
            cmd_type <= CMD_NONE;
        end else begin
            // Clear flags (pulse generation)
            send_pong <= 0;
            send_ok <= 0;

            // Clear uart_received after some time
            if (uart_received && blink_counter[23])
                uart_received <= 0;

            if (rx_valid) begin
                uart_received <= 1;

                case (rx_data)
                    8'hFF: begin  // PING
                        send_pong <= 1;
                        cmd_type <= CMD_PING;
                    end
                    8'h01: begin  // MODE (expect parameter)
                        cmd_type <= CMD_MODE;
                    end
                    default: begin
                        cmd_type <= CMD_NONE;
                    end
                endcase
            end
        end
    end

    // === PARAMETER RECEIVER (for MODE commands) ===
    // State machine to receive parameter byte after MODE command
    // UART byte time at 115200 baud = ~87 microseconds = 4340 clock cycles

    localparam PARAM_IDLE = 0;
    localparam PARAM_WAIT = 1;
    localparam PARAM_DONE = 2;

    reg [1:0] param_state = PARAM_IDLE;
    reg [12:0] param_timeout;     // 13 bits for 4340 cycles (~1 UART byte time)
    reg mode_cmd_pending = 0;     // MODE command detected, waiting for param

    always @(posedge clk) begin
        if (rst) begin
            param_state <= PARAM_IDLE;
            mode_cmd_pending <= 0;
        end else begin
            case (param_state)
                PARAM_IDLE: begin
                    if (cmd_type == CMD_MODE) begin
                        param_state <= PARAM_WAIT;
                        param_timeout <= 4340;   // ~87 microseconds timeout
                        mode_cmd_pending <= 1;
                    end
                end

                PARAM_WAIT: begin
                    if (rx_valid && mode_cmd_pending) begin
                        // Apply the parameter - set LED mode
                        led_mode_reg <= rx_data[1:0];
                        send_ok <= 1;           // Send OK response
                        param_state <= PARAM_DONE;
                    end else if (param_timeout == 0) begin
                        param_state <= PARAM_IDLE;  // Timeout
                        mode_cmd_pending <= 0;
                    end else begin
                        param_timeout <= param_timeout - 1;
                    end
                end

                PARAM_DONE: begin
                    param_state <= PARAM_IDLE;
                    mode_cmd_pending <= 0;
                end
            endcase
        end
    end

    // === LFSR (for chaotic LED mode) ===
    // 32-bit LFSR for pseudo-random pattern generation
    reg [31:0] lfsr = 32'hDEAD_BEEF;
    wire lfsr_feedback = lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0];

    always @(posedge clk)
        lfsr <= {lfsr[30:0], lfsr_feedback};

    // === LED CONTROL ===
    // 4 modes (via MODE command 0x01 XX):
    //   00: SEPARABLE - clean periodic blink (~1.5 Hz)
    //   01: VIOLATION - chaotic/irregular (LFSR-driven)
    //   10: ZERO - slow/constant (~0.75 Hz)
    //   11: NEGATIVE - fast blink (~3 Hz)

    reg [25:0] blink_counter = 0;
    always @(posedge clk)
        blink_counter <= blink_counter + 1;

    // LED output based on led_mode_reg
    assign led = (led_mode_reg == 2'b00) ? ~blink_counter[25] :    // SEPARABLE: ~1.5 Hz
                (led_mode_reg == 2'b01) ? ~lfsr[0] :          // VIOLATION: Chaotic
                (led_mode_reg == 2'b10) ? ~blink_counter[22] :    // ZERO: ~0.75 Hz
                ~blink_counter[21];                            // NEGATIVE: ~3 Hz

    // === UART TX (PONG and OK responses) ===
    // Responds to PING (0xFF) with 0xAA PONG
    // Responds to MODE commands with 0x00 OK
    reg [7:0] tx_data;
    reg [3:0] tx_state = 0;
    reg [15:0] tx_counter = 0;
    reg tx_busy = 0;
    wire tx = (tx_state != 0) ? tx_data[0] : 1'b1;

    always @(posedge clk) begin
        if (rst) begin
            tx_state <= 0;
            tx_busy <= 0;
        end else begin
            case (tx_state)
                0: begin  // Idle
                    if ((send_pong || send_ok) && !tx_busy) begin
                        tx_data <= send_pong ? 8'hAA : 8'h00;  // PONG or OK
                        tx_state <= 1;
                        tx_counter <= 0;
                        tx_busy <= 1;
                    end
                end
                1: begin  // Start bit (LOW)
                    if (tx_counter == BAUD_DIV - 1) begin
                        tx_counter <= 0;
                        tx_state <= 2;
                    end else begin
                        tx_counter <= tx_counter + 1;
                    end
                end
                2: begin  // Data bits (LSB first)
                    if (tx_counter == BAUD_DIV - 1) begin
                        tx_counter <= 0;
                        tx_data <= {1'b1, tx_data[7:1]};
                        if (tx_data[7:1] == 7'b1111111)
                            tx_state <= 3;
                    end else begin
                        tx_counter <= tx_counter + 1;
                    end
                end
                3: begin  // Stop bit (HIGH)
                    if (tx_counter == BAUD_DIV - 1) begin
                        tx_state <= 0;
                        tx_busy <= 0;
                    end else begin
                        tx_counter <= tx_counter + 1;
                    end
                end
            endcase
        end
    end

    assign uart_tx = tx;

endmodule

// φ² + 1/φ² = 3 = TRINITY
