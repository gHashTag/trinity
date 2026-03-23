// ============================================================================
// CLOCK TEST — Verify 50MHz oscillator is working
//
// Direct connection: LED tied to clock signal
// If clock works, LED will show blur (~50MHz too fast to see)
// If LED is solid, clock is not working
// ============================================================================

`default_nettype none

module clock_test (
    input  wire clk,    // 50 MHz on U22
    output wire t23,    // T23 LED
    output wire r23     // R23 LED
);

    // Direct clock connection - if clock works, LED should be blurry
    assign t23 = clk;
    assign r23 = ~clk;  // Inverted clock

endmodule
