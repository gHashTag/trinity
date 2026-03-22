// UART Loopback Top Module
// QMTech XC7A100T FGG676 Core Board
// Instantiates uart_loopback_core

`timescale 1ns/1ps

module uart_loopback(
    input  wire clk,
    input  wire uart_rx,
    output wire uart_tx,
    output wire led
);

    uart_loopback_core core_inst (
        .clk(clk),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .led(led)
    );

endmodule
