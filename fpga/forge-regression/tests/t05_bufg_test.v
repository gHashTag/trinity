// Test 05: BUFG Clock Buffer
// Feature: Explicit BUFG instantiation
// Expected: LED blinking at ~1.5 Hz
module trinity_top (
    input  wire clk_pin,
    output wire led
);
    wire clk;

    // Explicit BUFG
    BUFG bufg_inst (
        .I(clk_pin),
        .O(clk)
    );

    reg [24:0] counter = 25'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    assign led = counter[24];
endmodule
