// Test multiple LEDs at once
module trinity_top (
    input  wire clk,
    output wire led0,
    output wire led1,
    output wire led2,
    output wire led3,
    output wire led4,
    output wire led5
);
    // All ON (active-low test)
    assign led0 = 1'b0;
    assign led1 = 1'b0;
    assign led2 = 1'b0;
    assign led3 = 1'b0;
    assign led4 = 1'b0;
    assign led5 = 1'b0;
endmodule
