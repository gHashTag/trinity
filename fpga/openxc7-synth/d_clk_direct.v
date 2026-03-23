//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// Direct clock to LED - diagnostic test
module trinity_top (
    input  wire clk,
    output wire led
);
    // Connect LED directly to clock (should see dim/blur at 50MHz)
    assign led = clk;
endmodule
