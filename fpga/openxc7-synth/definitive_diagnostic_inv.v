//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ============================================================================
// DEFINITIVE LED DIAGNOSTIC v2 — WITH INVERSION
//
// v1 detected SOLID ON → LEDs are active-low, need inversion
//
// Tests BOTH pins with different rates + INVERTED outputs:
//   T23: Fast blink (~6 Hz) - INVERTED
//   R23: Slow blink (~1.5 Hz) - INVERTED
// ============================================================================

`default_nettype none

module definitive_diagnostic_top (
    input  wire clk,    // 50 MHz oscillator on U22
    output wire t23,    // T23 (D6 LED) - FAST blink - INVERTED
    output wire r23     // R23 (D5 LED) - SLOW blink - INVERTED
);

    // 26-bit counter for timing divisions
    reg [25:0] counter = 26'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // Different blink rates for identification:
    // Bit 22: 50MHz / 2^23 = ~5.96 Hz (FAST) - for T23
    // Bit 24: 50MHz / 2^25 = ~1.49 Hz (SLOW) - for R23

    // T23: Fast blink (~6 Hz) - ACTIVE-LOW (inverted)
    assign t23 = ~counter[22];

    // R23: Slow blink (~1.5 Hz) - ACTIVE-LOW (inverted)
    assign r23 = ~counter[24];

endmodule
