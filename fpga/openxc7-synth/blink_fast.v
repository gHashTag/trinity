`timescale 1ns / 1ps

// Very fast blink - should be visible blur
// 16-bit counter = 65536 cycles @ 50MHz = ~0.0013 seconds (~760 Hz)
// Should see LED as dim or flickering
module trinity_top (
    input  wire clk,
    output wire led
);

    reg [15:0] counter = 16'h0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // Toggle LSB directly (fastest visible toggle)
    assign led = counter[0];

endmodule
