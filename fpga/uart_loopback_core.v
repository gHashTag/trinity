// UART Loopback for QMTech XC7A100T FGG676 Core Board
// Clock: M22 (U22 for LiteX)
// UART: D26/E26 (Bank 35)

module uart_loopback(
    input  wire clk,
    input  wire uart_rx,
    output wire uart_tx,
    output wire led
);

    // Loopback: receive -> transmit
    assign uart_tx = uart_rx;

    // LED shows data activity
    assign led = uart_rx;

endmodule
