// =========================================================================
// TRINITY FPGA — QMTECH XC7A100T Core Board LED Blink
// Minimal test: LED heartbeat (no reset button — Core Board has no SW1)
// Clock: 50 MHz (M22) | LED: J19 (active-low)
// phi^2 + 1/phi^2 = 3 = TRINITY
// =========================================================================

`timescale 1ns / 1ps
`default_nettype none

module trinity_top (
    input  wire clk,     // 50 MHz system clock (M22)
    output wire led      // User LED D5 (J19, active-low)
);

    reg [25:0] counter = 26'd0;

    // LED heartbeat: blink ~1.5 Hz (50MHz / 2^25 ~ 1.49 Hz)
    // Active-low LED: invert counter bit so LED visibly blinks
    assign led = ~counter[24];

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

endmodule
