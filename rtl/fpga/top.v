// TRINITY OS v1.0 Top Module — iCE40-HX8K-TQFP144
module trinity_top (
    input wire clk_12mhz, rst_n,
    output wire [7:0] led
);
SB_PLL40_CORE #(
    .FEEDBACK_PATH("SIMPLE"),
    .DIVR(4'b0000),
    .DIVF(7'b1000011),
    .DIVQ(3'b101)
) pll (
    .REFCLK(clk_12mhz),
    .PLLOUTGLOBAL()
);
trinity_led_controller led_ctrl (
    .clk(), .rst_n(rst_n),
    .pattern(2'b00), .led(led)
);
endmodule