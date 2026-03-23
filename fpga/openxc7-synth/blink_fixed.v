//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ============================================================================
// BLINK FIXED — Correct clock pin for QMTECH Wukong board
//
// Root cause: XDC used U22, but Wukong board has clock on M22 (V1/V2)
// This version uses M22 with CLOCK_DEDICATED_ROUTE FALSE workaround
//
// LEDs confirmed ACTIVE-HIGH:
// - T23 (D6/Right) = ON when logic 1
// - R23 (D5/Left) = ON when logic 1
// ============================================================================

`default_nettype none

module blink_fixed (
    input  wire sys_clk,  // 50 MHz on M22 (Wukong V1/V2)
    output wire led       // T23 (D6) - use R23 for D5
);

    // Explicit BUFG for clock buffering
    wire clk_buf;
    BUFG bufg_inst (
        .I(sys_clk),
        .O(clk_buf)
    );

    // 26-bit counter at 50MHz
    // Bit 25: 2^25 / 50MHz ≈ 1.34 seconds period = ~0.75 Hz blink
    reg [25:0] counter = 26'd0;

    always @(posedge clk_buf) begin
        counter <= counter + 1'b1;
    end

    // Active-high LED (confirmed via hardware tests)
    assign led = counter[25];

endmodule
