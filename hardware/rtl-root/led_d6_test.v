`default_nettype none

// Test D6 LED on pin R23
module trinity_top (
    input  wire clk,
    output wire led
);
    // Active-HIGH for testing (will try both)
    assign led = 1'b1;
endmodule
