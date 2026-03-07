`timescale 1ns / 1ps

// Simple LED ON test - no counter, just direct connection
module trinity_top (
    input  wire clk,
    output wire led
);

// Direct assignment: led = 0 means LED ON (active-low)
assign led = 1'b0;

endmodule
