// UART Echo Top Module for QMTech XC7A100T FGG676C
// Implements PING protocol: 0x03 -> 0x83
// Pins: M22(clk), K20(RX), L20(TX), T23(LED)
// UART: 115200 baud, 8N1

`timescale 1ns/1ps

module uart_echo_top(
    input  wire clk,        // M22 - 50 MHz system clock
    input  wire uart_rx,     // K20 - UART RX from ESP32/Mac
    output wire uart_tx,     // L20 - UART TX to ESP32/Mac
    output wire led          // T23 - Activity LED
);

    // Parameters
    localparam CLK_FREQ = 50_000_000;
    localparam BAUD_RATE = 115_200;
    localparam BIT_CYCLES = CLK_FREQ / BAUD_RATE;  // ~434 cycles per bit
    localparam UART_IDLE = 1'b1;
    localparam UART_START = 1'b0;

    // RX oversampling (16 samples per bit)
    localparam OVERSAMPLE = 16;
    localparam SAMPLE_CYCLES = BIT_CYCLES / OVERSAMPLE;  // ~27 cycles per sample

    // UART RX state
    reg [2:0] rx_state;
    reg [7:0] rx_shift;
    reg [3:0] rx_bit_count;
    reg [7:0] rx_sample;
    reg [11:0] baud_counter;

    // UART TX state
    reg [2:0] tx_state;
    reg [7:0] tx_shift;
    reg [3:0] tx_bit_count;
    reg [11:0] tx_counter;
    reg tx_busy;

    // Echo response
    reg [7:0] echo_data;
    reg echo_pending;

    // LED
    reg led_reg;

    // UART TX output
    reg uart_tx_reg;
    assign uart_tx = uart_tx_reg;

    // State definitions
    localparam S_IDLE = 3'd0;
    localparam S_START = 3'd1;
    localparam S_DATA = 3'd2;
    localparam S_STOP = 3'd3;
    localparam S_WAIT = 3'd4;

    // RX State Machine with oversampling
    always @(posedge clk) begin
        // Default: increment sample counter
        if (rx_state != S_IDLE) begin
            if (baud_counter < SAMPLE_CYCLES - 1)
                baud_counter <= baud_counter + 1;
            else begin
                baud_counter <= 0;
                rx_sample <= rx_sample + 1;
                
                // Sample in middle of bit period
                if (rx_sample == OVERSAMPLE/2) begin
                    if (rx_state == S_START) begin
                        // Start bit detected, move to data
                        rx_state <= S_DATA;
                        rx_bit_count <= 0;
                        rx_shift <= 8'h00;
                    end else if (rx_state == S_DATA) begin
                        // Capture data bit (LSB first)
                        rx_shift[rx_bit_count] <= uart_rx;
                        if (rx_bit_count == 7)
                            rx_state <= S_STOP;
                        else
                            rx_bit_count <= rx_bit_count + 1;
                    end
                end
                
                // End of bit period
                if (rx_sample == OVERSAMPLE - 1) begin
                    if (rx_state == S_STOP) begin
                        rx_state <= S_IDLE;
                        // Check for PING (0x03)
                        if (rx_shift == 8'h03) begin
                            echo_data <= 8'h83;  // PONG response
                            echo_pending <= 1;
                        end
                    end
                end
            end
        end else begin
            // IDLE state - look for start bit
            if (uart_rx == UART_START) begin
                rx_state <= S_START;
                baud_counter <= 0;
                rx_sample <= 0;
            end
        end
    end

    // LED activity indicator
    always @(posedge clk) begin
        led_reg <= (rx_state != S_IDLE) | (tx_state != S_IDLE);
    end

    // TX State Machine
    always @(posedge clk) begin
        case (tx_state)
            S_IDLE: begin
                uart_tx_reg <= UART_IDLE;
                if (echo_pending && !tx_busy) begin
                    tx_state <= S_START;
                    tx_shift <= echo_data;
                    tx_busy <= 1;
                    tx_counter <= 0;
                    tx_bit_count <= 0;
                    echo_pending <= 0;
                end else if (!tx_busy) begin
                    tx_busy <= 0;
                end
            end
            
            S_START: begin
                uart_tx_reg <= UART_START;
                if (tx_counter == BIT_CYCLES - 1) begin
                    tx_state <= S_DATA;
                    tx_counter <= 0;
                end else begin
                    tx_counter <= tx_counter + 1;
                end
            end
            
            S_DATA: begin
                uart_tx_reg <= tx_shift[0];
                if (tx_counter == BIT_CYCLES - 1) begin
                    tx_shift <= {1'b0, tx_shift[7:1]};  // Shift right
                    if (tx_bit_count == 7) begin
                        tx_state <= S_STOP;
                    end else begin
                        tx_bit_count <= tx_bit_count + 1;
                    end
                    tx_counter <= 0;
                end else begin
                    tx_counter <= tx_counter + 1;
                end
            end
            
            S_STOP: begin
                uart_tx_reg <= UART_IDLE;
                if (tx_counter == BIT_CYCLES - 1) begin
                    tx_state <= S_IDLE;
                    tx_busy <= 0;
                end else begin
                    tx_counter <= tx_counter + 1;
                end
            end
            
            default: tx_state <= S_IDLE;
        endcase
    end

    // LED output
    assign led = led_reg;

endmodule
