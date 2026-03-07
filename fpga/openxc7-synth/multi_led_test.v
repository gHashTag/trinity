// Test multiple LED pins to find actual D6
// Based on singularity XDC and various tested pins
module trinity_top (
    input  wire clk,
    output wire led0,   // T23 - singularity D6
    output wire led1,   // R23 - tried before
    output wire led2,   // G22 - tried before
    output wire led3,   // D21 - tried before
    output wire led4,   // E21 - tried before
    output wire led5,   // F19 - tried before
    output wire led7,   // L22 - new
    output wire led8    // M22 - new (incorrect clock)
);

reg [23:0] counter = 24'd0;

always @(posedge clk) begin
    counter <= counter + 1'b1;
end

// Different blink rates for each pin to identify
assign led0 = counter[23];  // T23 - ~6 Hz
assign led1 = counter[22];  // R23 - ~12 Hz
assign led2 = counter[21];  // G22 - ~24 Hz
assign led3 = counter[20];  // D21 - ~48 Hz
assign led4 = counter[19];  // E21 - ~96 Hz
assign led5 = counter[18];  // F19 - ~192 Hz
assign led7 = counter[23];  // L22 - same as T23
assign led8 = 1'b0;         // M22 - OFF (not valid LED)

endmodule
