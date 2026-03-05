// FPGA Test Reporter
// Sends test results via UART for automated hardware verification
// Format: "PASS:test_name\n" or "FAIL:test_name:reason\n"

module fpga_test_reporter #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD = 115200
)(
    input wire clk,
    input wire rst,
    output wire uart_tx,
    output wire led  // Status LED indicator
);

    // Test states
    localparam IDLE = 0;
    localparam SEND_RESULT = 1;
    localparam WAITING = 2;

    reg [2:0] state;
    reg [7:0] char_to_send;
    reg start_tx;
    wire tx_busy;
    reg [4:0] char_idx;
    reg led_reg;

    // UART transmitter instance
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) uart (
        .clk(clk),
        .rst(rst),
        .data(char_to_send),
        .start(start_tx),
        .uart_tx(uart_tx),
        .busy(tx_busy)
    );

    // Test result strings (stored in ROM)
    // Modify these for your specific test
    function [7:0] get_char;
        input [4:0] idx;
        begin
            case (idx)
                // "PASS:test\n"
                0:  get_char = "P";
                1:  get_char = "A";
                2:  get_char = "S";
                3:  get_char = "S";
                4:  get_char = ":";
                5:  get_char = "t";
                6:  get_char = "e";
                7:  get_char = "s";
                8:  get_char = "t";
                9:  get_char = "\n";
                default: get_char = 8'h00;
            endcase
        end
    endfunction

    // Blink LED to show activity
    reg [23:0] blink_counter;
    always @(posedge clk) begin
        if (rst) begin
            blink_counter <= 0;
        end else begin
            blink_counter <= blink_counter + 1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            char_idx <= 0;
            start_tx <= 0;
            led_reg <= 1;  // Active-low: 1 = OFF
        end else begin
            case (state)
                IDLE: begin
                    // Wait before sending test result
                    if (blink_counter == 24'h0) begin
                        state <= SEND_RESULT;
                        char_idx <= 0;
                    end
                end

                SEND_RESULT: begin
                    if (!tx_busy && char_idx < 10) begin
                        char_to_send <= get_char(char_idx);
                        start_tx <= 1;
                        char_idx <= char_idx + 1;
                    end else if (!tx_busy && char_idx >= 10) begin
                        // Done sending
                        state <= WAITING;
                        led_reg <= 0;  // LED ON (active-low) = test passed
                    end else begin
                        start_tx <= 0;
                    end
                end

                WAITING: begin
                    // Blink slowly to indicate test passed
                    if (blink_counter[23] == 1) begin
                        led_reg <= ~led_reg;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign led = led_reg;

endmodule
