// Test 03: Single FF Toggle
// Feature: Single flip-flop dividing clock by 2
// Expected: 25 MHz blink
module trinity_top (
    input  wire clk,
    output wire led
);
    reg q = 0;

    always @(posedge clk) begin
        q <= ~q;
    end

    assign led = q;
endmodule
