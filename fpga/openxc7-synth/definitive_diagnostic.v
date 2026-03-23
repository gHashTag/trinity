//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ============================================================================
// DEFINITIVE LED DIAGNOSTIC — Test both pins with different rates
//
// This design helps identify:
// 1. Which pin (T23 or R23) has a working LED
// 2. Whether LEDs are active-high or active-low
//
// Expected behavior:
//   T23 LED should blink FAST (~6 Hz)
//   R23 LED should blink SLOW (~1.5 Hz)
//
// If you see LEDs always ON → they are active-low, need inversion
// If you see LEDs always OFF → wrong pins or no clock
// ============================================================================

`default_nettype none

module definitive_diagnostic_top (
    input  wire clk,    // 50 MHz oscillator on U22
    output wire t23,    // T23 (D6 LED) - FAST blink
    output wire r23     // R23 (D5 LED) - SLOW blink
);

    // 26-bit counter for timing divisions
    reg [25:0] counter = 26'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // Different blink rates for identification:
    // Bit 22: 50MHz / 2^23 = ~5.96 Hz (FAST) - for T23
    // Bit 24: 50MHz / 2^25 = ~1.49 Hz (SLOW) - for R23

    // T23: Fast blink (~6 Hz) - active-high
    assign t23 = counter[22];

    // R23: Slow blink (~1.5 Hz) - active-high
    assign r23 = counter[24];

endmodule
