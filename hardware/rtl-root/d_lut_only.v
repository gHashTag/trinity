// LUT-only blink (no flip-flops)
module trinity_top (
    input  wire clk,
    output wire led
);
    // Direct LUT: LED = ~clk (inverter)
    assign led = ~clk;
endmodule
