`default_nettype none

// ═════════════════════════════════════════════════════════════════
// test_top.v - FIXED: Added LED heartbeat for blinking
// Pin mapping: LED on T23 (active-low)
// φ² + 1/φ² = 3 | TRINITY

module test_top_fixed (
    input  wire clk,          // 50 MHz onboard crystal (U22)
    output wire led           // LED T23 (active-low)
);

    // ====================================================================
    // CLOCK DIVIDER for LED heartbeat (1 Hz blink)
    // ====================================================================
    reg [25:0] clk_div = 26'h0;
    always @(posedge clk) begin
        clk_div <= clk_div + 26'h1;
    end

    // LED heartbeat (1 Hz)
    wire led_heartbeat = clk_div[25];  // 50MHz / 2^26 ≈ 0.74 Hz
    assign led = ~led_heartbeat;   // INVERT for active-low LED!

endmodule
