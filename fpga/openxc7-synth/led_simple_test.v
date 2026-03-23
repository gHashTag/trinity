//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`default_nettype none
// Simple LED test - same as working design
module led_simple_test (
    input  wire clk,
    output wire led
);
    assign led = 1'b1;  // Always ON
endmodule
