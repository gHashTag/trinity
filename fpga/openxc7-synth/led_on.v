`default_nettype none

// Simplest possible test: LED always ON
// No clock, no logic — just wire output LOW (active-low LED)
module trinity_top (
    input  wire clk,
    output wire led
);
    // Active-low: 0 = LED ON, 1 = LED OFF
    assign led = 1'b0;
endmodule
