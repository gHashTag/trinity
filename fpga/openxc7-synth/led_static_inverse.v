//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ============================================================================
// LED STATIC INVERSE TEST — Determine polarity
//
// Test OPPOSITE of led_static_test:
//   - t23 = 0 (was 1)
//   - r23 = 1 (was 0)
//
// If T23 LED changes state → T23 is active-high
// If T23 LED stays same → T23 is active-low or wrong pin
// ============================================================================

`default_nettype none

module led_static_inverse (
    input  wire clk,    // Unused but required
    output wire t23,
    output wire r23
);

    // INVERSE of led_static_test
    assign t23 = 1'b0;  // Was 1, now 0
    assign r23 = 1'b1;  // Was 0, now 1

endmodule
