// ============================================================================
// UART Bridge for J2 Header (FT232RL → K20/L20)
// QMTECH XC7A100T-1FGG676C
// ============================================================================
// Protocol:
//   - PING:  0x03 → 0x83 (PONG)
//   - ECHO:  All bytes echoed back
//   - LED:   Flashes 50ms on byte reception
// ============================================================================

module uart_bridge_top (
    input  wire clk,       // M22, 50 MHz oscillator
    input  wire uart_rx,   // L20 (from FT232RL TXD)
    output wire uart_tx,   // K20 (to FT232RL RXD)
    output wire led        // T23, active-low LED
);

    // ============================================================================
    // Parameters
    // ============================================================================
    localparam CLK_FREQ     = 50_000_000;
    localparam BAUD_RATE   = 115200;
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;  // 434

    // ============================================================================
    // RX State Machine
    // ============================================================================
    localparam RX_IDLE  = 0;
    localparam RX_START = 1;
    localparam RX_BITS  = 2;
    localparam RX_STOP  = 3;

    reg [3:0]  rx_state   = RX_IDLE;
    reg [15:0] rx_cnt     = 0;
    reg [7:0]  rx_byte    = 0;
    reg [2:0]  rx_bit_idx = 0;
    reg        rx_valid   = 0;
    reg [2:0]  rx_sync    = 3'b111;

    // Double-flop synchronizer for uart_rx
    always @(posedge clk) begin
        rx_sync <= {rx_sync[1:0], uart_rx};
    end

    // RX FSM
    always @(posedge clk) begin
        rx_valid <= 0;

        case (rx_state)
            RX_IDLE: begin
                if (rx_sync[1] == 0) begin  // Start bit
                    rx_cnt   <= CLKS_PER_BIT / 2;
                    rx_state <= RX_START;
                end
            end

            RX_START: begin
                if (rx_cnt == 0) begin
                    rx_cnt     <= CLKS_PER_BIT;
                    rx_bit_idx <= 0;
                    rx_state   <= RX_BITS;
                end else begin
                    rx_cnt <= rx_cnt - 1;
                end
            end

            RX_BITS: begin
                if (rx_cnt == 0) begin
                    rx_byte[rx_bit_idx] <= rx_sync[1];
                    if (rx_bit_idx == 7) begin
                        rx_cnt   <= CLKS_PER_BIT;
                        rx_state <= RX_STOP;
                    end else begin
                        rx_bit_idx <= rx_bit_idx + 1;
                        rx_cnt     <= CLKS_PER_BIT;
                    end
                end else begin
                    rx_cnt <= rx_cnt - 1;
                end
            end

            RX_STOP: begin
                if (rx_cnt == 0) begin
                    rx_valid <= 1;
                    rx_state <= RX_IDLE;
                end else begin
                    rx_cnt <= rx_cnt - 1;
                end
            end
        endcase
    end

    // ============================================================================
    // TX State Machine (with PING/PONG)
    // ============================================================================
    localparam TX_IDLE  = 0;
    localparam TX_START = 1;
    localparam TX_BITS  = 2;
    localparam TX_STOP  = 3;

    reg [3:0]  tx_state   = TX_IDLE;
    reg [15:0] tx_cnt     = 0;
    reg [7:0]  tx_byte    = 0;
    reg [2:0]  tx_bit_idx = 0;
    reg        tx_out     = 1;
    reg        tx_busy    = 0;

    assign uart_tx = tx_out;

    // PING/PONG: 0x03 → 0x83
    wire is_ping = (rx_valid && rx_byte == 8'h03);

    // TX FSM
    always @(posedge clk) begin
        case (tx_state)
            TX_IDLE: begin
                if (rx_valid && !tx_busy) begin
                    // PING response
                    if (rx_byte == 8'h03)
                        tx_byte <= 8'h83;
                    else
                        tx_byte <= rx_byte;

                    tx_out   <= 0;
                    tx_cnt   <= CLKS_PER_BIT;
                    tx_busy  <= 1;
                    tx_state <= TX_START;
                end
            end

            TX_START: begin
                if (rx_cnt == 0) begin
                    tx_out     <= tx_byte[0];
                    tx_cnt     <= CLKS_PER_BIT;
                    tx_bit_idx <= 0;
                    tx_state   <= TX_BITS;
                end else begin
                    tx_cnt <= rx_cnt - 1;
                end
            end

            TX_BITS: begin
                if (rx_cnt == 0) begin
                    if (tx_bit_idx == 7) begin
                        tx_out   <= 1;
                        tx_cnt   <= CLKS_PER_BIT;
                        tx_state <= TX_STOP;
                    end else begin
                        tx_bit_idx <= tx_bit_idx + 1;
                        tx_out     <= tx_byte[tx_bit_idx + 1];
                        tx_cnt     <= CLKS_PER_BIT;
                    end
                end else begin
                    tx_cnt <= rx_cnt - 1;
                end
            end

            TX_STOP: begin
                if (rx_cnt == 0) begin
                    tx_busy  <= 0;
                    tx_state <= TX_IDLE;
                end else begin
                    tx_cnt <= rx_cnt - 1;
                end
            end
        endcase
    end

    // ============================================================================
    // LED Flash (50ms on byte reception)
    // ============================================================================
    localparam LED_FLASH_CYCLES = 50_000_000 / 20;  // 2.5M cycles = 50ms @ 50MHz
    reg [25:0] led_cnt = 0;
    reg        led_on   = 0;

    always @(posedge clk) begin
        if (rx_valid) begin
            led_cnt <= LED_FLASH_CYCLES;
            led_on   <= 1;
        end else if (led_cnt > 0) begin
            led_cnt <= led_cnt - 1;
        end else begin
            led_on <= 0;
        end
    end

    // LED is active-low
    assign led = ~led_on;

endmodule
