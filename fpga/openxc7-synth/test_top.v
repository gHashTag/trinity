//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ============================================================================
// TEST TOP — Simple LED Blink (1 Hz)
// ============================================================================
//
// Simple 1 Hz LED blink for easy visual verification
// 50 MHz clock → 25-bit counter (2^25 = 33,554,432 → ~0.67 sec per toggle)
//
// Target: QMTECH Artix-7 XC7A100T-1FGG676C
// Clock: 50 MHz (U22)
// LED: T23
//
// φ² + 1/φ² = 3 = TRINITY
//
// ============================================================================

`default_nettype none

module test_top(
    input  wire clk,          // 50 MHz oscillator
    output wire led           // LED T23
);

    // 25-bit counter for ~1 Hz blink (50 MHz / 2^25 ≈ 1.5 Hz)
    reg [24:0] counter = 25'd0;
    reg led_state = 1'b0;

    always @(posedge clk) begin
        counter <= counter + 25'd1;

        // Toggle at bit 24 (2^24 = 16,777,216 → ~0.33 sec period)
        // Or use comparison for more precise timing
        if (counter == 25'd25000000) begin  // 0.5 second at 50 MHz
            counter <= 25'd0;
            led_state <= ~led_state;
        end
    end

    // ACTIVE-LOW LED: invert (0 = ON, 1 = OFF)
    assign led = ~led_state;

endmodule

`default_nettype wire
