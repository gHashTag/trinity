// Test with inverted output
module trinity_top (
    input  wire clk,
    output wire led
);
    // Test: active-high (1 = ON)
    assign led = 1'b1;
endmodule
