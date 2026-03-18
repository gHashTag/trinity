// UART Transmitter for FPGA Debugging
// Simple 8-N-1 UART transmitter (8 data bits, no parity, 1 stop bit)
// Suitable for: FPGA test result reporting, real-time debugging

module uart_tx #(
    parameter CLK_FREQ = 50_000_000,  // 50 MHz default
    parameter BAUD = 115200            // Baud rate
)(
    input wire clk,          // System clock
    input wire rst,          // Active-high reset
    input wire [7:0] data,   // Data to transmit
    input wire start,        // Start transmission (pulse high for 1 cycle)
    output reg uart_tx,      // UART TX line
    output reg busy          // Busy flag (1 = transmitting)
);

    // Baud rate divisor
    localparam DIVISOR = CLK_FREQ / BAUD;

    // State machine
    localparam IDLE = 0;
    localparam START = 1;
    localparam DATA = 2;
    localparam STOP = 3;

    reg [31:0] counter;
    reg [2:0] state;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            counter <= 0;
            bit_idx <= 0;
            shift_reg <= 8'd0;
            uart_tx <= 1;
            busy <= 0;
        end else begin
            counter <= counter + 1;

            case (state)
                IDLE: begin
                    uart_tx <= 1;  // Idle high
                    if (start && !busy) begin
                        shift_reg <= data;
                        bit_idx <= 0;
                        state <= START;
                        busy <= 1;
                        counter <= 0;
                    end else begin
                        busy <= 0;
                    end
                end

                START: begin
                    uart_tx <= 0;  // Start bit
                    if (counter >= DIVISOR - 1) begin
                        counter <= 0;
                        state <= DATA;
                    end
                end

                DATA: begin
                    uart_tx <= shift_reg[bit_idx];
                    if (counter >= DIVISOR - 1) begin
                        counter <= 0;
                        bit_idx <= bit_idx + 1;
                        if (bit_idx == 7) begin
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    uart_tx <= 1;  // Stop bit
                    if (counter >= DIVISOR - 1) begin
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
