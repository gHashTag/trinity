// ============================================================================
// LED ON TEST — Simplest possible test
// Just turn LED ON steady - no clock, no counter
// ============================================================================

`default_nettype none

module led_on_test_top (
    output wire led    // T23 - try active LOW
);

    // Try active LOW (0 = ON)
    assign led = 1'b0;

endmodule
