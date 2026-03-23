//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

module trinity_top (
    input  wire clk,
    output wire led
);
    assign led = 1'b0;  // ON for active-low
endmodule
