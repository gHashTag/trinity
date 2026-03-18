// Test 09: Bank Crossing
// Feature: Signals crossing IO banks (Bank 13 -> Bank 14/15/16)
// Expected: All LEDs blink in sequence
module trinity_top (
    input  wire clk,
    output wire led_bank13,
    output wire led_bank14,
    output wire led_bank15
);
    reg [24:0] counter = 25'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // LED in different banks with phase shift
    assign led_bank13 = counter[23];
    assign led_bank14 = counter[22];
    assign led_bank15 = counter[21];
endmodule
