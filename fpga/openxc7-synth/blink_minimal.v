//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ============================================================================
// BLINK MINIMAL — Simplest possible blink test
//
// Uses direct clock division with minimal logic
// If this doesn't work, the clock itself is the problem
// ============================================================================

`default_nettype none

module blink_minimal (
    input  wire clk,     // 50 MHz on U22
    output wire t23,     // Right LED D6
    output wire r23      // Left LED D5
);

    // Very simple counters - no BUFG needed for such slow division
    reg [23:0] fast_div = 24'd0;
    reg [25:0] slow_div = 26'd0;

    always @(posedge clk) begin
        fast_div <= fast_div + 1'b1;
        slow_div <= slow_div + 1'b1;
    end

    // Direct connection - no inversion
    assign t23 = fast_div[23];  // ~3 Hz blink
    assign r23 = slow_div[25];  // ~0.75 Hz blink

endmodule
