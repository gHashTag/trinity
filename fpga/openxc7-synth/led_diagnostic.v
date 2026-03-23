//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ============================================================================
// LED DIAGNOSTIC — Identify which LED is which pin
// phi^2 + 1/phi^2 = 3 = TRINITY
//
// Clock:    50 MHz (QMTECH Artix-7 XC7A100T)
// LED0:     T23 (fast blink ~6 Hz)
// LED1:     R23 (slow blink ~1.5 Hz)
//
// If you see fast blink, that's T23
// If you see slow blink, that's R23
// ============================================================================

`default_nettype none

module led_diagnostic_top (
    input  wire clk,    // 50 MHz
    output wire led0,   // T23
    output wire led1    // R23
);

    // Counter for timing
    reg [24:0] counter = 25'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // LED0: Fast blink (~6 Hz) - counter[22] = 50MHz / 2^23 = ~5.96 Hz
    // LED1: Slow blink (~1.5 Hz) - counter[24] = 50MHz / 2^25 = ~1.49 Hz
    assign led0 = counter[22];   // T23 - FAST
    assign led1 = counter[24];   // R23 - SLOW

endmodule
