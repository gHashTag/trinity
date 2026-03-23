`timescale 1ns / 1ps

// Blink using internal oscillator (no external clock required)
// Uses MMCME2 base to generate ~50 MHz internal clock
module trinity_top (
    input  wire clk,     // Unused (external clock not connected)
    output wire led
);

    // Internal clock using MMCME2 base oscillator
    wire clk_fb;
    wire clk_out;
    wire locked;

    // MMCME2_BASE: Internal oscillator
    // Input: grounded (no external clock)
    // Output: ~100 MHz from internal oscillator
    MMCME2_BASE #(
        .CLKFBOUT_MULT_F(8.0),      // Multiply by 8
        .CLKIN1_PERIOD(10.0),       // Input period (ns) - dummy
        .CLKOUT0_DIVIDE_F(4.0),     // Divide by 4 → 100 MHz
        .DIVCLK_DIVIDE(1)           // No divide
    ) mmcme2_inst (
        .CLKIN1(1'b0),              // Grounded input
        .CLKOUT0(clk_out),          // Output clock
        .CLKFBIN(clk_fb),
        .CLKFBOUT(clk_fb),
        .PWRDWN(1'b0),
        .RST(1'b0),
        .LOCKED(locked)
    );

    // Blink using internal clock
    reg [25:0] counter = 26'h0;
    reg led_state = 1'b0;

    always @(posedge clk_out) begin
        counter <= counter + 1'b1;
        if (counter == 26'h0) begin
            led_state <= ~led_state;
        end
    end

    assign led = ~led_state;  // Active-low

endmodule
