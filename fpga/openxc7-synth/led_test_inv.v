//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`default_nettype none

// Test: LED always ON (active-HIGH)
module trinity_top (
    input  wire clk,
    output wire led
);
    // Try HIGH = LED ON
    assign led = 1'b1;
endmodule
