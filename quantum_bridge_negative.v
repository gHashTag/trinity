// ============================================================================
// QUANTUM BRIDGE TEMPLATE — Dynamic Quantum State (set during build)
// phi^2 + 1/phi^2 = 3 = TRINITY
//
// Clock:    50 MHz (QMTECH Artix-7 XC7A100T)
// LED:      D5 (T23) - Active LOW
//
// Quantum States (QUANTUM_STATE parameter):
//   00 = SEPARABLE   -> Medium blink (~3 Hz) - classical physics
//   01 = VIOLATION   -> Fast chaos (~6 Hz) - CGLMP > 2.0 (quantum!)
//   10 = ZERO        -> Slow blink (~0.4 Hz) - orthogonal
//   11 = NEGATIVE    -> Steady ON - anti-correlated
//
// Build system replaces QUANTUM_STATE value during build
// ============================================================================

`default_nettype none

module quantum_bridge_top (
    input  wire clk,   // 50 MHz
    output wire led    // D5 (T23) - Active LOW
);

    // ========================================================================
    // QUANTUM STATE — SET DURING BUILD BY build_all_quantum_states.sh
    // ========================================================================
    localparam QUANTUM_STATE = 2'b11;  // Replaced by sed during build

    // ========================================================================
    // COUNTER FOR BLINK RATES
    // 26-bit counter gives precise timing at 50MHz
    // ========================================================================
    reg [25:0] counter = 26'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // ========================================================================
    // LED PATTERN BASED ON QUANTUM STATE
    // Uses different counter bits for different blink rates:
    //   counter[22] = 5.96 Hz (fast - VIOLATION)
    //   counter[23] = 2.98 Hz (medium - SEPARABLE)
    //   counter[24] = 1.49 Hz (slow)
    //   counter[25] = 0.74 Hz (very slow - ZERO)
    // ========================================================================
    reg led_pattern;

    always @(*) begin
        case (QUANTUM_STATE)
            2'b00: led_pattern = counter[23];   // SEPARABLE: ~3 Hz
            2'b01: led_pattern = counter[22];   // VIOLATION: ~6 Hz
            2'b10: led_pattern = counter[25];   // ZERO: ~0.4 Hz
            2'b11: led_pattern = 1'b0;         // NEGATIVE: ON
            default: led_pattern = 1'b1;        // OFF
        endcase
    end

    // Active-low LED output (0 = ON, 1 = OFF)
    assign led = ~led_pattern;

endmodule
