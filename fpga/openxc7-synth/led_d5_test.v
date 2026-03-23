//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`default_nettype none

// ============================================================================
// LED D5 Test — Trinity V2 Day 6 Simple Test
// ============================================================================
// Tests LED D5 (J19) at ~3 Hz blink rate
// Uses QMTECH XC7A100T-1FGG676C pinout
// ============================================================================

module trinity_top (
    input  wire clk,
    output wire led
);
    // Blink counter — 50MHz / 2^23 ≈ 6 Hz toggle = ~3 Hz blink
    reg [23:0] blink_counter;

    always @(posedge clk) begin
        blink_counter <= blink_counter + 1'b1;
    end

    // LED blinks at counter bit 23
    assign led = blink_counter[23];

endmodule
