// =============================================================================
// UART Bridge Fixed — FT232RL ↔ FPGA Direct Connection
// Pin mapping for QMTech XC7A100T-1FGG676C
// =============================================================================
// FT232RL Wiring:
//   RXD (green)  → J2 pin 5  → L20 → FPGA uart_tx
//   TXD (white)  → J2 pin 6  → K20 → FPGA uart_rx
//   GND (black) → J2 pin 1  → GND
// =============================================================================

module uart_bridge_fixed (
    input  wire clk,           // 50 MHz (M22)
    input  wire uart_rx,       // From FT232RL TXD (K20)
    output wire uart_tx,       // To FT232RL RXD (L20)
    output wire led            // Status LED (T23)
);

    // ========================================================================
    // UART Configuration — 115200 baud @ 50 MHz
    // ========================================================================
    localparam CLK_FREQ = 50_000_000;
    localparam BAUD_RATE = 115200;
    localparam BIT_DIV = CLK_FREQ / BAUD_RATE;  // 434

    // ========================================================================
    // UART Receiver (from FT232RL TXD)
    // ========================================================================
    reg [15:0] rx_cnt = 0;
    reg [3:0]  rx_bit = 0;      // 0=idle, 1-8=data
    reg [7:0]  rx_shift = 0;
    reg [7:0]  rx_byte = 0;
    reg        rx_valid = 0;

    // Synchronizer
    reg rx_sync1 = 1, rx_sync2 = 1;
    always @(posedge clk) begin
        rx_sync1 <= uart_rx;
        rx_sync2 <= rx_sync1;
    end

    always @(posedge clk) begin
        rx_valid <= 0;
        if (rx_bit == 0) begin
            if (rx_sync2 == 0) rx_bit <= 1;
        end else begin
            if (rx_cnt == 0) begin
                rx_cnt <= BIT_DIV;
                if (rx_bit >= 2 && rx_bit <= 9) begin
                    rx_shift <= {rx_sync2, rx_shift[7:1]};
                    rx_bit <= rx_bit + 1;
                end else begin
                    rx_byte <= rx_shift;
                    rx_valid <= 1;
                    rx_bit <= 0;
                end
            end else begin
                rx_cnt <= rx_cnt - 1;
            end
        end
    end

    // ========================================================================
    // UART Transmitter (to FT232RL RXD)
    // ========================================================================
    reg [15:0] tx_cnt = 0;
    reg [3:0]  tx_bit = 0;
    reg [9:0]  tx_shift = 10'h3FF; // idle high
    reg [7:0]  tx_byte = 0;
    reg        tx_start = 0;
    reg        tx_ready = 1;

    assign uart_tx = tx_shift[0];

    always @(posedge clk) begin
        tx_start <= 0;
        if (tx_bit == 0) begin
            tx_ready <= 1;
            if (tx_start) begin
                tx_shift <= {1'b1, tx_byte, 1'b0};
                tx_bit <= 1;
                tx_cnt <= BIT_DIV;
                tx_ready <= 0;
            end
        end else begin
            if (tx_cnt == 0) begin
                tx_cnt <= BIT_DIV;
                tx_shift <= {1'b1, tx_shift[9:1]};
                if (tx_bit == 10) begin
                    tx_bit <= 0;
                end else begin
                    tx_bit <= tx_bit + 1;
                end
            end else begin
                tx_cnt <= tx_cnt - 1;
            end
        end
    end

    // ========================================================================
    // Echo Logic — received byte transmitted back
    // ========================================================================
    always @(posedge clk) begin
        if (rx_valid && tx_ready) begin
            tx_byte <= rx_byte;
            tx_start <= 1;
        end
    end

    // ========================================================================
    // LED — flash on byte received (active-low)
    // ========================================================================
    reg [23:0] led_cnt = 0;
    reg led_on = 0;

    always @(posedge clk) begin
        if (rx_valid) begin
            led_on <= 1;
            led_cnt <= 24'd5_000_000; // 100ms @ 50MHz
        end else if (led_cnt > 0) begin
            led_cnt <= led_cnt - 1;
        end else begin
            led_on <= 0;
        end
    end

    assign led = ~led_on; // active-low

endmodule
