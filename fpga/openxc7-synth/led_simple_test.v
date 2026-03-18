`default_nettype none
// Simple LED test - same as working design
module led_simple_test (
    input  wire clk,
    output wire led
);
    assign led = 1'b1;  // Always ON
endmodule
