//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// Test LED constantly ON
module trinity_top (
    input  wire clk,
    output wire led
);
    // Test: always ON (active-low means ~0 = 1)
    assign led = 1'b0;
endmodule
