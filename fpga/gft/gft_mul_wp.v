// Two-stage gft_mul_w. The product is registered, splitting the path into
// "multiply" and "renormalise + exponent", which are the two natural halves.
// Latency 1 cycle, one result per cycle.
`timescale 1ns / 1ps
`default_nettype none
module gft_mul_wp #(
    parameter integer MANT_W = 9, parameter integer OFF_W = 7,
    parameter [31:0] BIAS = 40, parameter [31:0] OFFSET_MAX = 80, parameter [31:0] MANT_ONE = 512
) (
    input  wire clk, input wire rst_n,
    input  wire [OFF_W-1:0]  a_off, input wire [MANT_W-1:0] a_mant,
    input  wire [OFF_W-1:0]  b_off, input wire [MANT_W-1:0] b_mant,
    output reg  [OFF_W-1:0]  out_off, output reg [MANT_W-1:0] out_mant
);
  localparam integer FM_W = MANT_W + 1, PROD_W = 2*FM_W, SUM_W = OFF_W + 2;

  wire [PROD_W-1:0] prod = {1'b1, a_mant} * {1'b1, b_mant};

  reg [PROD_W-1:0] prod_r;
  reg [OFF_W-1:0]  a_off_r, b_off_r;
  always @(posedge clk) begin
    if (!rst_n) begin prod_r <= {PROD_W{1'b0}}; a_off_r <= {OFF_W{1'b0}}; b_off_r <= {OFF_W{1'b0}}; end
    else        begin prod_r <= prod;           a_off_r <= a_off;          b_off_r <= b_off; end
  end

  wire carry = prod_r[PROD_W-1];
  wire [SUM_W-1:0] sum    = {{(SUM_W-OFF_W){1'b0}}, a_off_r} + {{(SUM_W-OFF_W){1'b0}}, b_off_r} + {{(SUM_W-1){1'b0}}, carry};
  wire [SUM_W-1:0] result = sum - BIAS[SUM_W-1:0];
  wire [OFF_W-1:0] off_n  = (sum < BIAS[SUM_W-1:0]) ? {OFF_W{1'b0}} :
                            (result >= OFFSET_MAX[SUM_W-1:0]) ? OFFSET_MAX[OFF_W-1:0] : result[OFF_W-1:0];
  wire [MANT_W-1:0] mant_n = carry ? prod_r[PROD_W-2 -: MANT_W] : prod_r[PROD_W-3 -: MANT_W];

  always @(posedge clk) begin
    if (!rst_n) begin out_off <= {OFF_W{1'b0}}; out_mant <= {MANT_W{1'b0}}; end
    else        begin out_off <= off_n;         out_mant <= mant_n; end
  end
endmodule
`default_nettype wire
