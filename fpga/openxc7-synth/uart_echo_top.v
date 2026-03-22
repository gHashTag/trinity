// ============================================================================
// UART Echo + Ping Top — CH340 UART Bridge Test
// ============================================================================
//
// Minimal UART design for testing tri fpga uart commands:
//   - Echoes all received bytes back (loopback)
//   - PING: 0x03 in → 0x83 out (PONG)
//   - LED ON when byte received (active-low)
//
// 115200 baud, 8-N-1, 50 MHz clock
// QMTECH XC7A100T-1FGG676C
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// ============================================================================

module uart_echo_top(
    input  wire clk,        // M22, 50 MHz
    input  wire uart_rx,    // E26 (J2 pin 6, from FT232RL TX)
    output wire uart_tx,    // D26 (J2 pin 5, to FT232RL RX)
    output wire led         // J19 (D5, active-low)
);

    // 115200 baud @ 50 MHz: 50_000_000 / 115_200 = 434
    localparam CLK_DIV = 434;
    localparam HALF_DIV = CLK_DIV / 2;

    // ── RX State Machine ──
    reg [15:0] rx_cnt = 0;
    reg [3:0]  rx_bit = 0;    // 0=idle, 1=start, 2-9=data, 10=stop
    reg [7:0]  rx_shift = 0;
    reg [7:0]  rx_byte = 0;
    reg        rx_valid = 0;

    // Synchronizer for uart_rx (avoid metastability)
    reg rx_sync1 = 1, rx_sync2 = 1;
    always @(posedge clk) begin
        rx_sync1 <= uart_rx;
        rx_sync2 <= rx_sync1;
    end

    always @(posedge clk) begin
        rx_valid <= 0;

        if (rx_bit == 0) begin
            // Idle — wait for start bit (falling edge)
            if (rx_sync2 == 0) begin
                rx_bit <= 1;
                rx_cnt <= HALF_DIV; // sample at midpoint
            end
        end else begin
            if (rx_cnt == 0) begin
                rx_cnt <= CLK_DIV;

                if (rx_bit == 1) begin
                    // Verify start bit is still low
                    if (rx_sync2 == 0)
                        rx_bit <= 2;
                    else
                        rx_bit <= 0; // false start
                end else if (rx_bit >= 2 && rx_bit <= 9) begin
                    // Sample data bits (LSB first)
                    rx_shift <= {rx_sync2, rx_shift[7:1]};
                    rx_bit <= rx_bit + 1;
                end else begin
                    // Stop bit — byte complete
                    rx_byte <= rx_shift;
                    rx_valid <= 1;
                    rx_bit <= 0;
                end
            end else begin
                rx_cnt <= rx_cnt - 1;
            end
        end
    end

    // ── TX State Machine ──
    reg [15:0] tx_cnt = 0;
    reg [3:0]  tx_bit = 0;    // 0=idle, 1-10=transmitting
    reg [9:0]  tx_shift = 10'h3FF; // idle high
    reg        tx_ready = 1;
    reg [7:0]  tx_byte = 0;
    reg        tx_start = 0;

    assign uart_tx = tx_shift[0];

    always @(posedge clk) begin
        tx_start <= 0;

        if (tx_bit == 0) begin
            tx_ready <= 1;
            if (tx_start) begin
                // Load: {stop, data[7:0], start}
                tx_shift <= {1'b1, tx_byte, 1'b0};
                tx_bit <= 1;
                tx_cnt <= CLK_DIV;
                tx_ready <= 0;
            end
        end else begin
            if (tx_cnt == 0) begin
                tx_cnt <= CLK_DIV;
                tx_shift <= {1'b1, tx_shift[9:1]}; // shift out LSB
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

    // ── Echo + Ping Logic ──
    // When byte received: if 0x03 → send 0x83 (PONG), else echo back
    always @(posedge clk) begin
        if (rx_valid && tx_ready) begin
            if (rx_byte == 8'h03)
                tx_byte <= 8'h83;  // PONG
            else
                tx_byte <= rx_byte; // echo
            tx_start <= 1;
        end
    end

    // ── LED: flash on byte received ──
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
