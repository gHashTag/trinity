// Test 08: Multi-LED Different Rates
// Feature: 4 LEDs at different blink rates
// Expected: Each LED blinks at different frequency
module trinity_top (
    input  wire clk,
    output wire led0,
    output wire led1,
    output wire led2,
    output wire led3
);
    reg [24:0] counter = 25'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    assign led0 = counter[24];  // ~1.5 Hz
    assign led1 = counter[22];  // ~6 Hz
    assign led2 = counter[20];  // ~24 Hz
    assign led3 = counter[18];  // ~96 Hz
endmodule
