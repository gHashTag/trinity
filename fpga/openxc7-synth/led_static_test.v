//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ============================================================================
// LED STATIC TEST — Both LEDs always ON (verify pins work)
//
// Simple test: tie LEDs to logical 1
// If LEDs light up, pins are correct
// If LEDs stay dark, pins are WRONG or LEDs are active-low
// ============================================================================

`default_nettype none

module led_static_test (
    input  wire clk,    // Unused but required
    output wire t23,
    output wire r23
);

    // Tie both LEDs to logical 1
    // If LEDs are active-high, they will turn ON
    // If LEDs are active-low, they will stay OFF
    assign t23 = 1'b1;
    assign r23 = 1'b0;  // Test opposite state for R23

endmodule
