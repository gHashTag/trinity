// =============================================================================
// UART Bridge: FPGA ↔ ESP32
// =============================================================================
// Baud Rate: 115200 (configurable)
// Data: 8-bit, No parity, 1 stop bit (8N1)
//
// ESP32 Pinout:
//   IO4  → TX (ESP32 sends to FPGA RX)
//   IO5  ← RX (ESP32 receives from FPGA TX)
//   GND → GND (critical!)
//
// Protocol:
//   CMD_VSA_CALC  (0x01) -> FPGA calculates VSA dot product
//   CMD_LED_CTRL  (0x02) -> Control LED state
//   CMD_PING      (0x03) -> FPGA responds with PONG
// =============================================================================

module uart_top #(
    parameter CLK_FREQ = 50_000_000,     // 50 MHz
    parameter BAUD_RATE = 115200          // Default baud
)(
    input wire clk,
    input wire rst,

    // UART Interface (to ESP32)
    input wire uart_rx,
    output wire uart_tx,

    // Status LED
    output wire led,

    // Debug outputs
    output wire [3:0] debug_state
);

    // ============================================================================
    // UART Transmitter
    // ============================================================================
    localparam CLK_DIV = CLK_FREQ / (16 * BAUD_RATE);  // Oversampling by 16

    reg [15:0] clk_div_counter;
    reg [3:0] bit_counter;
    reg [7:0] tx_shift_reg;
    reg tx_busy;
    reg tx_start;

    wire tx_ready = !tx_busy;

    // UART TX state machine
    localparam TX_IDLE  = 0;
    localparam TX_START = 1;
    localparam TX_DATA  = 2;
    localparam TX_STOP  = 3;

    reg [1:0] tx_state;
    reg [7:0] tx_data;
    reg uart_tx_reg;

    always @(posedge clk) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            tx_busy <= 0;
            uart_tx_reg <= 1;
            bit_counter <= 0;
            clk_div_counter <= 0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    uart_tx_reg <= 1;
                    if (tx_start) begin
                        tx_state <= TX_START;
                        tx_busy <= 1;
                        tx_shift_reg <= tx_data;
                        bit_counter <= 0;
                        clk_div_counter <= 0;
                        tx_start <= 0;
                    end
                end

                TX_START: begin
                    uart_tx_reg <= 0;  // Start bit
                    if (clk_div_counter == CLK_DIV - 1) begin
                        clk_div_counter <= 0;
                        tx_state <= TX_DATA;
                    end else begin
                        clk_div_counter <= clk_div_counter + 1;
                    end
                end

                TX_DATA: begin
                    uart_tx_reg <= tx_shift_reg[0];
                    if (clk_div_counter == CLK_DIV - 1) begin
                        clk_div_counter <= 0;
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        if (bit_counter == 7) begin
                            tx_state <= TX_STOP;
                        end else begin
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        clk_div_counter <= clk_div_counter + 1;
                    end
                end

                TX_STOP: begin
                    uart_tx_reg <= 1;  // Stop bit
                    if (clk_div_counter == CLK_DIV - 1) begin
                        tx_state <= TX_IDLE;
                        tx_busy <= 0;
                    end else begin
                        clk_div_counter <= clk_div_counter + 1;
                    end
                end
            endcase
        end
    end

    assign uart_tx = uart_tx_reg;

    // ============================================================================
    // UART Receiver with oversampling
    // ============================================================================
    reg [7:0] rx_shift_reg;
    reg [3:0] rx_bit_counter;
    reg [15:0] rx_clk_div;
    reg rx_busy;
    reg [7:0] rx_data;

    // UART RX state machine
    localparam RX_IDLE  = 0;
    localparam RX_START = 1;
    localparam RX_DATA  = 2;
    localparam RX_STOP  = 3;

    reg [1:0] rx_state;
    reg [3:0] rx_oversample;

    always @(posedge clk) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_busy <= 0;
            rx_data <= 0;
            rx_oversample <= 0;
        end else begin
            case (rx_state)
                RX_IDLE: begin
                    rx_busy <= 0;
                    if (!uart_rx) begin  // Start bit detected
                        rx_state <= RX_START;
                        rx_busy <= 1;
                        rx_clk_div <= 0;
                        rx_oversample <= 0;
                    end
                end

                RX_START: begin
                    if (rx_clk_div == CLK_DIV - 1) begin
                        rx_clk_div <= 0;
                        if (rx_oversample == 7) begin  // Sample at middle of bit
                            if (!uart_rx) begin  // Verify start bit
                                rx_state <= RX_DATA;
                                rx_bit_counter <= 0;
                            end else begin
                                rx_state <= RX_IDLE;  // False start bit
                            end
                        end else begin
                            rx_oversample <= rx_oversample + 1;
                        end
                    end else begin
                        rx_clk_div <= rx_clk_div + 1;
                    end
                end

                RX_DATA: begin
                    if (rx_clk_div == CLK_DIV - 1) begin
                        rx_clk_div <= 0;
                        if (rx_oversample == 15) begin
                            rx_shift_reg <= {uart_rx, rx_shift_reg[7:1]};
                            if (rx_bit_counter == 7) begin
                                rx_state <= RX_STOP;
                            end else begin
                                rx_bit_counter <= rx_bit_counter + 1;
                            end
                            rx_oversample <= 0;
                        end else begin
                            rx_oversample <= rx_oversample + 1;
                        end
                    end else begin
                        rx_clk_div <= rx_clk_div + 1;
                    end
                end

                RX_STOP: begin
                    if (rx_clk_div == CLK_DIV - 1) begin
                        rx_data <= rx_shift_reg;
                        rx_state <= RX_IDLE;
                    end else begin
                        rx_clk_div <= rx_clk_div + 1;
                    end
                end
            endcase
        end
    end

    // ============================================================================
    // Command Processor
    // ============================================================================
    localparam CMD_PING      = 8'h03;
    localparam CMD_LED_ON    = 8'h10;
    localparam CMD_LED_OFF   = 8'h11;
    localparam CMD_LED_BLINK = 8'h12;
    localparam CMD_VSA_DOT   = 8'h20;  // VSA dot product calculation

    localparam RESP_PONG     = 8'h83;
    localparam RESP_OK       = 8'hFF;
    localparam RESP_ACK      = 8'hAA;

    reg [7:0] response_data;
    reg send_response;
    reg led_reg;

    // Blink counter
    reg [23:0] blink_counter;
    wire blink_tick = (blink_counter == 50_000_000 - 1);  // 1 second at 50MHz

    always @(posedge clk) begin
        if (rst) begin
            led_reg <= 0;
            send_response <= 0;
            blink_counter <= 0;
        end else begin
            // Default: no response
            send_response <= 0;

            // Blink counter
            if (blink_tick)
                blink_counter <= 0;
            else
                blink_counter <= blink_counter + 1;

            // Process received byte
            if (!rx_busy && !tx_busy) begin
                case (rx_data)
                    CMD_PING: begin
                        response_data <= RESP_PONG;
                        send_response <= 1;
                    end

                    CMD_LED_ON: begin
                        led_reg <= 1;
                        response_data <= RESP_OK;
                        send_response <= 1;
                    end

                    CMD_LED_OFF: begin
                        led_reg <= 0;
                        response_data <= RESP_OK;
                        send_response <= 1;
                    end

                    CMD_LED_BLINK: begin
                        led_reg <= blink_tick ? ~led_reg : led_reg;
                        response_data <= RESP_ACK;
                        send_response <= 1;
                    end

                    CMD_VSA_DOT: begin
                        // Placeholder for VSA calculation
                        response_data <= RESP_ACK;
                        send_response <= 1;
                    end
                endcase
            end

            // Send response
            if (send_response && tx_ready) begin
                tx_data <= response_data;
                tx_start <= 1;
            end
        end
    end

    assign led = led_reg;
    assign debug_state = {tx_busy, rx_busy, tx_state[1:0]};

endmodule
