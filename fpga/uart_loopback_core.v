// UART Loopback for QMTech XC7A100T FGG676 Core Board
// Clock: M22 (50 MHz)
// UART: D26/E26 (Bank 15)
// Simple loopback: what we receive, we send back

`timescale 1ns/1ps

module uart_loopback_core(
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
