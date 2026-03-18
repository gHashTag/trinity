// UART Receiver for receiving commands
// Allows host PC to send commands to FPGA

module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD = 115200
)(
    input wire clk,
    input wire rst,
    input wire uart_rx,      // UART RX line
    output reg [7:0] data,   // Received data
    output reg data_valid,   // Data valid pulse (1 cycle)
    output reg framing_error // Framing error detected
);

    localparam DIVISOR = CLK_FREQ / BAUD;

    localparam IDLE = 0;
    localparam START = 1;
    localparam DATA = 2;
    localparam STOP = 3;

    reg [31:0] counter;
    reg [2:0] state;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;

    // Synchronizer for uart_rx
    reg [2:0] rx_sync;

    always @(posedge clk) begin
        rx_sync <= {rx_sync[1:0], uart_rx};
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            counter <= 0;
            bit_idx <= 0;
            shift_reg <= 8'd0;
            data <= 8'd0;
            data_valid <= 0;
            framing_error <= 0;
        end else begin
            data_valid <= 0;
            framing_error <= 0;
            counter <= counter + 1;

            case (state)
                IDLE: begin
                    if (rx_sync[1] == 0) begin  // Start bit detected
                        state <= START;
                        counter <= DIVISOR / 2;  // Sample at middle
                    end
                end

                START: begin
                    if (counter >= DIVISOR - 1) begin
                        counter <= 0;
                        if (rx_sync[1] == 0) begin
                            state <= DATA;
                            bit_idx <= 0;
                        end else begin
                            // False start bit
                            state <= IDLE;
                        end
                    end
                end

                DATA: begin
                    if (counter >= DIVISOR - 1) begin
                        counter <= 0;
                        shift_reg[bit_idx] <= rx_sync[1];
                        bit_idx <= bit_idx + 1;
                        if (bit_idx == 7) begin
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (counter >= DIVISOR - 1) begin
                        data <= shift_reg;
                        data_valid <= 1;
                        if (rx_sync[1] == 0) begin
                            framing_error <= 1;  // Stop bit should be high
                        end
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
