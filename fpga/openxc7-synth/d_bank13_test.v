//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// Same bank (13) routing test
module trinity_top (
    input  wire clk,
    output wire led
);
    assign led = clk;  // Direct connection
endmodule
