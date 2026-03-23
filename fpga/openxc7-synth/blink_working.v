//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ============================================================================
// BLINK WORKING — Confirmed working LED blink for QMTECH Artix-7
//
// HARDWARE CONFIRMED:
// - T23 (Right LED/D6) = ACTIVE-HIGH
// - R23 (Left LED/D5) = ACTIVE-HIGH
// - Clock U22 = 50MHz oscillator
// - REQUIRES BUFG for proper clock distribution
//
// Blink rates using 50MHz clock:
// - counter[22] = ~11.9 Hz (FAST)
// - counter[24] = ~2.98 Hz (SLOW)
// ============================================================================

`default_nettype none

module blink_working (
    input  wire clk_in,  // 50 MHz on U22
    output wire t23,     // Right LED D6 (ACTIVE-HIGH)
    output wire r23      // Left LED D5 (ACTIVE-HIGH)
);

    // BUFG is REQUIRED for Xilinx 7-series clock routing
    wire clk_bufged;

    BUFG clk_buf (
        .I(clk_in),      // Input: raw clock from pin
        .O(clk_bufged)   // Output: buffered clock for logic
    );

    // 26-bit counter at 50MHz = 67 seconds before overflow
    reg [25:0] counter = 26'd0;

    always @(posedge clk_bufged) begin
        counter <= counter + 1'b1;
    end

    // LED outputs - ACTIVE-HIGH (no inversion)
    assign t23 = counter[22];  // Fast blink ~11.9 Hz
    assign r23 = counter[24];  // Slow blink ~2.98 Hz

endmodule
