//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// LUT-only blink (no flip-flops)
module trinity_top (
    input  wire clk,
    output wire led
);
    // Direct LUT: LED = ~clk (inverter)
    assign led = ~clk;
endmodule
