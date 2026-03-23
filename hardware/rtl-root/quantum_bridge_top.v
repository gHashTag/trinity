// ============================================================================
// QUANTUM BRIDGE TOP — Test module with hardcoded VIOLATION mode
// This version demonstrates CGLMP violation (fast ~6 Hz blink)
// ============================================================================

`default_nettype none

module quantum_bridge_top (
    input  wire clk,   // 50 MHz
    input  wire rst_n, // Reset button SW1 (active low) - tied to VCC for auto-start
    output wire led    // D5 (J19) - Active LOW
);

    // Hardcoded QUANTUM STATE = VIOLATION (01)
    // Change to 2'b00 for separable, 2'b10 for zero, 2'b11 for negative
    wire [1:0] quantum_state = 2'b01;  // VIOLATION MODE!

    // Pull reset high (disabled) for auto-start
    wire rst_n_internal = 1'b1;

    quantum_bridge u_bridge (
        .clk(clk),
        .rst_n(rst_n_internal),
        .quantum_state(quantum_state),
        .led(led)
    );

endmodule
