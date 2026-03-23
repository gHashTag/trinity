//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`timescale 1ns / 1ps

// Direct clock test - LED shows clock state
// If clock is running, LED will be dim (50% duty at 25 MHz visible)
// If clock is stuck, LED will be steady
module trinity_top (
    input  wire clk,
    output wire led
);

// Direct connection - LED follows clock
assign led = clk;

endmodule
