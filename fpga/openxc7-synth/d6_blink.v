`default_nettype none

// D6 (R23) blinking ~3 Hz
module trinity_top (
    input  wire clk,   // 50 MHz on M22
    output wire led    // R23 = D6
);
    reg [24:0] counter = 25'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // Blink ~3 Hz: 50MHz / 2^24 = 2.98 Hz
    assign led = counter[24];
endmodule
