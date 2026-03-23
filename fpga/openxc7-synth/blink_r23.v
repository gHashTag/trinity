//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`timescale 1ns / 1ps

// Blink LED on R23 (D6) - PRIMARY LED
module trinity_top (
    input  wire clk,
    output wire led
);

    reg [25:0] counter = 26'h0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // Invert for active-low LED
    assign led = ~counter[25];

endmodule
