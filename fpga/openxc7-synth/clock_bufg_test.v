//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ============================================================================
// CLOCK + BUFG TEST — Add Global Clock Buffer (REQUIRED for Xilinx 7-series)
//
// Xilinx 7-series requires BUFG for proper clock distribution.
// Without BUFG, clock signal doesn't reach the logic properly.
// ============================================================================

`default_nettype none

module clock_bufg_test (
    input  wire clk_in, // 50 MHz on U22
    output wire t23,     // T23 LED
    output wire r23      // R23 LED
);

    // BUFG is REQUIRED for Xilinx 7-series clock routing
    wire clk_bufged;

    // Instantiate Global Clock Buffer
    BUFG clk_buf (
        .I(clk_in),      // Input: raw clock from pin
        .O(clk_bufged)   // Output: buffered clock for logic
    );

    // 26-bit counter using BUFGED clock
    reg [25:0] counter = 26'd0;

    always @(posedge clk_bufged) begin
        counter <= counter + 1'b1;
    end

    // LED outputs (active-low, inverted)
    assign t23 = ~counter[22];  // Fast blink (~6 Hz)
    assign r23 = ~counter[24];  // Slow blink (~1.5 Hz)

endmodule
