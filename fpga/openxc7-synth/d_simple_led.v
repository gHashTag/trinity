module trinity_top (
    input  wire clk,
    output wire led
);
    assign led = 1'b0;  // ON for active-low
endmodule
