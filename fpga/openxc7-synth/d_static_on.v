//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// WORKING: Static ON (we verified this works)
module trinity_top (
    input  wire clk,
    output wire led
);
    assign led = 1'b0;  // Active-low = ON
endmodule
