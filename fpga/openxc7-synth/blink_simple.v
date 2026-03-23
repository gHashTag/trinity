//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`timescale 1ns / 1ps

// Simple blink using toggle register
// Period = 2^25 cycles @ 50MHz = 0.67 sec (~1.5 Hz)
module trinity_top (
    input  wire clk,
    output wire led
);

    reg [25:0] counter = 26'h0;
    reg led_state = 1'b0;  // Start with LED OFF

    always @(posedge clk) begin
        counter <= counter + 1'b1;
        if (counter == 26'h0) begin
            led_state <= ~led_state;  // Toggle at overflow
        end
    end

    // Invert for active-low LED
    assign led = ~led_state;

endmodule
