// =========================================================================
// TRINITY FPGA — QMTECH XC7A100T Core Board LED Blink
// Minimal test: LED heartbeat + sacred constant proof
// Clock: 50 MHz | LED: J19 | Button: H19 (active-low reset)
// phi^2 + 1/phi^2 = 3 = TRINITY
// =========================================================================

`timescale 1ns / 1ps

module trinity_top (
    input  wire clk,     // 50 MHz system clock (M22)
    input  wire rst_n,   // Active-low reset button (H19)
    output wire led      // User LED D5 (J19)
);

    reg [25:0] counter;

    // LED heartbeat: blink ~1.5 Hz (50MHz / 2^25 ~ 1.49 Hz)
    // Bit 24 = ~3 Hz, Bit 25 = ~1.5 Hz
    assign led = counter[24];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            counter <= 26'd0;
        else
            counter <= counter + 1'b1;
    end

endmodule
