// Test 04: Counter
// Feature: 25-bit counter with multiple tap points
// Expected: LED blinking at ~1.5 Hz
module trinity_top (
    input  wire clk,
    output wire led
);
    reg [24:0] counter = 25'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    assign led = counter[24];
endmodule
