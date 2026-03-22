// D21 LED blinking ~3 Hz (active-high test)
module trinity_top (
    input  wire clk,
    output wire led
);
    reg [24:0] counter = 25'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // Blink ~3 Hz - NO inversion (active-high)
    assign led = counter[24];
endmodule
