// ============================================================================
// BLINK RING OSCILLATOR — Internal clock source (no external clock needed)
//
// Uses a ring of inverters to generate internal oscillation
// This tests if LEDs work WITHOUT external clock
// ============================================================================

`default_nettype none

module blink_ring_osc (
    input  wire clk_dummy,  // Not used - required for XDC
    output wire t23,        // Right LED D6
    output wire r23         // Left LED D5
);

    // Ring oscillator - odd number of inverters creates oscillation
    wire osc_ring;
    reg [26:0] counter = 27'd0;

    // Three inverters in a ring (minimum for oscillation)
    // In simulation this won't work, but in real FPGA it will oscillate
    // at a high frequency (100s of MHz to GHz depending on PVT)
    wire inv1, inv2, inv3;

    // Use LUT as inverter
    assign inv1 = ~osc_ring;
    assign inv2 = ~inv1;
    assign inv3 = ~inv2;
    assign osc_ring = ~inv3;  // Close the loop

    // Use the ring oscillator as clock
    always @(posedge osc_ring) begin
        counter <= counter + 1'b1;
    end

    // LED outputs - use different counter bits
    assign t23 = counter[20];  // Medium blink
    assign r23 = counter[23];  // Slow blink

endmodule
