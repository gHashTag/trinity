// =============================================================================
// SACRED BLINKER — KOSCHEI ON SILICON
// =============================================================================
//
// phi^2 + 1/phi^2 = 3 = TRINITY
//
// LED blinks at sacred phi ratio:
//   ON  period: 1.618s (phi seconds)
//   OFF period: 1.000s (1 second)
//   Total cycle: 2.618s (phi + 1 = phi^2)
//
// Target: QMTECH XC7A100T Core Board
//   Clock: 50 MHz (M22)
//   LED:   J19 (active-low — LED on when output = 0)
//
// =============================================================================

module sacred_blinker (
    input  wire clk,    // 50 MHz
    output wire led     // Active-low LED D5
);

    // Sacred constants (in clock cycles at 50 MHz):
    //   phi   = 1.6180339... -> 80_901_699 cycles
    //   1.0s  = 50_000_000 cycles
    //   Total = 130_901_699 cycles
    localparam PHI_CYCLES = 27'd80_901_699;   // 1.618s ON
    localparam ONE_CYCLES = 27'd50_000_000;   // 1.000s OFF
    localparam TOTAL      = 27'd130_901_699;  // phi + 1 = phi^2

    reg [26:0] counter = 27'd0;
    reg        phase   = 1'b1;   // 1 = ON (LED active), 0 = OFF

    always @(posedge clk) begin
        if (counter >= TOTAL - 1) begin
            counter <= 27'd0;
        end else begin
            counter <= counter + 27'd1;
        end

        // Phase: ON for phi seconds, OFF for 1 second
        if (counter < PHI_CYCLES)
            phase <= 1'b1;
        else
            phase <= 1'b0;
    end

    // Active-low: LED on when phase=1 -> output 0
    assign led = ~phase;

endmodule
