// UART Loopback for QMTech XC7A100T FGG676 Core Board
// Clock: M22 (50 MHz)
// UART: D26/E26 (Bank 35) - Loopback test

// FT232RL connections:
// FT232RL [20] VCC -> FPGA VCC (pin 2 - bank 0)
// FT232RL [ 2]  GND  -> FPGA GND (pins 19, 20 - bank 0)
// FT232RL [ 4]  TDO -> FPGA TDO (pin 6 - bank 0)
// FT232RL [ 6]  TDI -> FPGA TDI (pin 8 - bank 0)
// FT232RL [ 8]  TMS -> FPGA TMS (pin 10 - bank 0)
// FT232RL [10]  TCK -> FPGA TCK (pin 12 - bank 0)

`timescale 1ns/1ns
`default_nettype none

uart_loopback_core uart_loopback_inst (
    .clk(clk),
    .uart_rx(uart_rx),
    .uart_tx(uart_tx),
    .led(led)
);

endmodule
