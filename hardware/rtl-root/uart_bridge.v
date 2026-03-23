// =============================================================================
// Simple UART Bridge: FPGA ↔ ESP32
// =============================================================================
// No external reset required - uses internal power-on reset
//
// ESP32 Wiring:
//   ESP32 GPIO4 (TX) -----> FPGA uart_rx (Pin L20)
//   ESP32 GPIO5 (RX) <----- FPGA uart_tx (Pin K20)
//   ESP32 GND      -----> FPGA GND (CRITICAL!)
//
// Test Commands (send from ESP32):
//   0x03 -> PING (FPGA responds with 0x83)
//   0x10 -> LED ON
//   0x11 -> LED OFF
//   0x12 -> LED BLINK
// =============================================================================

module uart_bridge (
    input wire clk,           // 50 MHz (Pin U22)
    input wire uart_rx,       // From ESP32 TX (Pin L20)
    output wire uart_tx,      // To ESP32 RX (Pin K20)
    output wire led           // Status LED (Pin T23)
);

    // System reset (power-on reset ~ 1ms)
    reg [15:0] reset_counter;
    wire rst = (reset_counter < 16'hFFFF);
    always @(posedge clk) reset_counter <= reset_counter + 1;

    // ============================================================================
    // UART Configuration
    // ============================================================================
    localparam CLK_FREQ = 50_000_000;
    localparam BAUD_RATE = 115200;
    localparam CLK_DIV = CLK_FREQ / (16 * BAUD_RATE);  // ~27

    // ============================================================================
    // UART Transmitter
    // ============================================================================
    reg [7:0] tx_data;
    reg tx_start;
    reg tx_busy;
    reg uart_tx_reg;
    reg [7:0] tx_shift_reg;
    reg [3:0] tx_bit_cnt;
    reg [15:0] tx_clk_cnt;

    localparam TX_IDLE = 0, TX_START = 1, TX_DATA = 2, TX_STOP = 3;
    reg [1:0] tx_state;

    always @(posedge clk) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            tx_busy <= 0;
            uart_tx_reg <= 1;
            tx_bit_cnt <= 0;
            tx_clk_cnt <= 0;
            tx_start <= 0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    uart_tx_reg <= 1;
                    if (tx_start) begin
                        tx_state <= TX_START;
                        tx_busy <= 1;
                        tx_shift_reg <= tx_data;
                        tx_bit_cnt <= 0;
                        tx_clk_cnt <= 0;
                        tx_start <= 0;
                    end
                end

                TX_START: begin
                    uart_tx_reg <= 0;
                    if (tx_clk_cnt == CLK_DIV - 1) begin
                        tx_clk_cnt <= 0;
                        tx_state <= TX_DATA;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end
                end

                TX_DATA: begin
                    uart_tx_reg <= tx_shift_reg[0];
                    if (tx_clk_cnt == CLK_DIV - 1) begin
                        tx_clk_cnt <= 0;
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        if (tx_bit_cnt == 7) begin
                            tx_state <= TX_STOP;
                        end else begin
                            tx_bit_cnt <= tx_bit_cnt + 1;
                        end
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end
                end

                TX_STOP: begin
                    uart_tx_reg <= 1;
                    if (tx_clk_cnt == CLK_DIV - 1) begin
                        tx_state <= TX_IDLE;
                        tx_busy <= 0;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1;
                    end
                end
            endcase
        end
    end

    assign uart_tx = uart_tx_reg;

    // ============================================================================
    // UART Receiver
    // ============================================================================
    reg [7:0] rx_data;
    reg rx_valid;
    reg [7:0] rx_shift_reg;
    reg [3:0] rx_bit_cnt;
    reg [15:0] rx_clk_cnt;
    reg [3:0] rx_sample;

    localparam RX_IDLE = 0, RX_START = 1, RX_DATA = 2, RX_STOP = 3;
    reg [1:0] rx_state;

    always @(posedge clk) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_valid <= 0;
            rx_clk_cnt <= 0;
            rx_sample <= 0;
        end else begin
            rx_valid <= 0;
            case (rx_state)
                RX_IDLE: begin
                    if (!uart_rx) begin
                        rx_state <= RX_START;
                        rx_clk_cnt <= 0;
                        rx_sample <= 0;
                    end
                end

                RX_START: begin
                    if (rx_clk_cnt == CLK_DIV - 1) begin
                        rx_clk_cnt <= 0;
                        if (rx_sample == 7 && !uart_rx) begin
                            rx_state <= RX_DATA;
                            rx_bit_cnt <= 0;
                        end else if (rx_sample < 15) begin
                            rx_sample <= rx_sample + 1;
                        end else begin
                            rx_state <= RX_IDLE;  // False start bit
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end
                end

                RX_DATA: begin
                    if (rx_clk_cnt == CLK_DIV - 1) begin
                        rx_clk_cnt <= 0;
                        if (rx_sample == 15) begin
                            rx_shift_reg <= {uart_rx, rx_shift_reg[7:1]};
                            if (rx_bit_cnt == 7) begin
                                rx_state <= RX_STOP;
                            end else begin
                                rx_bit_cnt <= rx_bit_cnt + 1;
                            end
                            rx_sample <= 0;
                        end else begin
                            rx_sample <= rx_sample + 1;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
                    end
                end

                RX_STOP: begin
                    if (rx_clk_cnt == CLK_DIV - 1) begin
                        rx_data <= rx_shift_reg;
                        rx_valid <= 1;
                        rx_state <= RX_IDLE;
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1;
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

    localparam RESP_PONG     = 8'h83;
    localparam RESP_OK       = 8'hFF;
    localparam RESP_ACK      = 8'hAA;

    reg [7:0] resp_data;
    reg send_resp;
    reg led_reg;
    reg [25:0] blink_cnt;

    always @(posedge clk) begin
        if (rst) begin
            led_reg <= 0;
            send_resp <= 0;
            blink_cnt <= 0;
        end else begin
            send_resp <= 0;

            // Blink counter (~0.75s)
            if (blink_cnt == 50_000_000 * 3 / 4 - 1)
                blink_cnt <= 0;
            else
                blink_cnt <= blink_cnt + 1;

            // Process command
            if (rx_valid && !tx_busy) begin
                case (rx_data)
                    CMD_PING: begin
                        resp_data <= RESP_PONG;
                        send_resp <= 1;
                    end

                    CMD_LED_ON: begin
                        led_reg <= 1;
                        resp_data <= RESP_OK;
                        send_resp <= 1;
                    end

                    CMD_LED_OFF: begin
                        led_reg <= 0;
                        resp_data <= RESP_OK;
                        send_resp <= 1;
                    end

                    CMD_LED_BLINK: begin
                        if (blink_cnt == 0)
                            led_reg <= ~led_reg;
                        resp_data <= RESP_ACK;
                        send_resp <= 1;
                    end

                    default: begin
                        resp_data <= rx_data;  // Echo
                        send_resp <= 1;
                    end
                endcase
            end

            // Send response
            if (send_resp && !tx_busy) begin
                tx_data <= resp_data;
                tx_start <= 1;
            end
        end
    end

    assign led = led_reg;

endmodule
