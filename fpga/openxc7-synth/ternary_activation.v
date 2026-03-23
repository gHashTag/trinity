//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// TERNARY ACTIVATION — Streaming ReLU
// =============================================================================
// out = (in > 0) ? in : 0
// 1-clock pipeline: valid/data/done all delayed by 1 cycle
// ~10 LUT, 0 BRAM, 0 DSP
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module ternary_activation #(
    parameter WIDTH = 20
)(
    input  wire                      clk,
    input  wire                      rst,
    input  wire                      valid_in,
    input  wire signed [WIDTH-1:0]   data_in,
    input  wire                      done_in,
    output reg                       valid_out,
    output reg  signed [WIDTH-1:0]   data_out,
    output reg                       done_out
);

    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            data_out  <= {WIDTH{1'b0}};
            done_out  <= 1'b0;
        end else begin
            valid_out <= valid_in;
            done_out  <= done_in;
            // ReLU: clamp negative to zero, pass positive through
            data_out  <= (data_in > 0) ? data_in : {WIDTH{1'b0}};
        end
    end

endmodule
