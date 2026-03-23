// ============================================================================
// LED BOTH TEST — Drive BOTH T23 and R23
// Try all combinations
// ============================================================================

`default_nettype none

module led_both_test_top (
    output wire led_t23,    // T23
    output wire led_r23     // R23
);

    // Try both active LOW (0 = ON)
    assign led_t23 = 1'b0;   // T23 LOW = ON
    assign led_r23 = 1'b1;   // R23 HIGH = OFF (try one on, one off)

endmodule
