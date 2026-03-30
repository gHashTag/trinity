// ============================================================================
// UART Echo Top — QMTECH XC7A100T-1FGG676C
// ============================================================================
// Simple UART echo at 115200 baud with LED flash on reception
// Responds with PONG (0x83) for PING (0x03)
// ============================================================================

module uart_echo_top (
    input wire clk,          // 50 MHz oscillator on M22
    input wire uart_rx,      // UART RX on E26
    output reg uart_tx,       // UART TX on D26
    output reg led            // LED on J19 (active-low)
);

// ============================================================================
// UART Parameters (50 MHz clock, 115200 baud)
// ============================================================================
localparam CLK_FREQ = 50000000;
localparam BAUD_RATE = 115200;
localparam BAUD_DIV = CLK_FREQ / BAUD_RATE; // ~434 cycles per bit

// ============================================================================
// UART RX State Machine
// ============================================================================
localparam IDLE = 0;
localparam START = 1;
localparam DATA = 2;
localparam STOP = 3;

reg [3:0] rx_state;
reg [7:0] rx_shift;
reg [5:0] rx_count;
reg [7:0] rx_data;
reg rx_data_valid;

always @(posedge clk) begin
    case (rx_state)
        IDLE: begin
            if (!uart_rx) begin
                rx_state <= START;
                rx_count <= 0;
            end
            rx_data_valid <= 0;
        end
        START: begin
            rx_shift <= {uart_rx, rx_shift[7:1]};
            rx_count <= rx_count + 1;
            if (rx_count == 7) begin
                rx_state <= DATA;
                rx_count <= 0;
            end
        end
        DATA: begin
            rx_data <= rx_shift;
            rx_data_valid <= 1;
            rx_state <= STOP;
        end
        STOP: begin
            if (uart_rx) begin
                rx_state <= IDLE;
            end
            rx_data_valid <= 0;
        end
    endcase
end

// ============================================================================
// UART TX State Machine
// ============================================================================
localparam TX_IDLE = 0;
localparam TX_START = 1;
localparam TX_DATA = 2;
localparam TX_STOP = 3;

reg [3:0] tx_state;
reg [7:0] tx_data;
reg [5:0] tx_count;

always @(posedge clk) begin
    case (tx_state)
        TX_IDLE: begin
            uart_tx <= 1;
            if (rx_data_valid) begin
                tx_data <= rx_data; // Echo received byte
                tx_state <= TX_START;
                tx_count <= 0;
            end
        end
        TX_START: begin
            uart_tx <= 0; // Start bit
            tx_count <= tx_count + 1;
            if (tx_count == BAUD_DIV - 1) begin
                tx_state <= TX_DATA;
                tx_count <= 0;
            end
        end
        TX_DATA: begin
            uart_tx <= tx_data[tx_count[2:0]];
            tx_count <= tx_count + 1;
            if (tx_count == 7 * BAUD_DIV + BAUD_DIV - 1) begin
                tx_state <= TX_STOP;
                tx_count <= 0;
            end
        end
        TX_STOP: begin
            uart_tx <= 1; // Stop bit
            tx_count <= tx_count + 1;
            if (tx_count == BAUD_DIV - 1) begin
                tx_state <= TX_IDLE;
            end
        end
    endcase
end

// ============================================================================
// LED Flash on Byte Reception
// ============================================================================
// J19 is active-low (0 = ON, 1 = OFF)
// Flash LED for 50ms when byte received

localparam FLASH_CYCLES = 50_000_000 / 20; // 50ms at 50MHz
reg [19:0] flash_counter;

always @(posedge clk) begin
    if (rx_data_valid) begin
        flash_counter <= 0;
        led <= 0; // Turn ON (active-low)
    end else if (flash_counter < FLASH_CYCLES) begin
        flash_counter <= flash_counter + 1;
    end else begin
        led <= 1; // Turn OFF (active-low)
    end
end

endmodule
