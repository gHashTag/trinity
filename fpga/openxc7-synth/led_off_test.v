//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`timescale 1ns / 1ps

// LED OFF test - led = 1 means LED OFF (active-low)
module trinity_top (
    input  wire clk,
    output wire led
);

assign led = 1'b1;

endmodule
