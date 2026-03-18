// Test 06: SRL16E Shift Register
// Feature: SRL16E as 16-bit shift register
// Expected: LED blinking at ~762 Hz
module trinity_top (
    input  wire clk,
    output wire led
);
    wire [15:0] shift_out;

    // SRL16E with 4-bit address (depth 16)
    SRL16E #(
        .INIT(16'h0001)
    ) srl_inst (
        .CLK(clk),
        .CE(1'b1),
        .D(1'b0),
        .A0(1'b1),
        .A1(1'b1),
        .A2(1'b1),
        .A3(1'b1),
        .Q(shift_out[0])
    );

    // Cascade for visual effect
    assign led = shift_out[0];
endmodule
