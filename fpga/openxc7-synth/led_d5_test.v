`default_nettype none

// Test D5 LED on pin J19 (active-low = 0 for ON)
module trinity_top (
    input  wire clk,
    output wire led
);
    // Active-low: 0 = LED ON
    assign led = 1'b0;
endmodule
