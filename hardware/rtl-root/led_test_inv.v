`default_nettype none

// Test: LED always ON (active-HIGH)
module trinity_top (
    input  wire clk,
    output wire led
);
    // Try HIGH = LED ON
    assign led = 1'b1;
endmodule
