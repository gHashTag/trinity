// Test LED constantly ON
module trinity_top (
    input  wire clk,
    output wire led
);
    // Test: always ON (active-low means ~0 = 1)
    assign led = 1'b0;
endmodule
