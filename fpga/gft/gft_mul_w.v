// gft_mul with the bus widths the arithmetic actually needs.
//
// The original declares every port 32 bits wide. Nothing in GF-T16 is 32 bits:
// the mantissa field is 9 bits, so (MANT_ONE + mant) is 10, their product is 20,
// and the exponent offset tops out at OFFSET_MAX = 80, which is 7. Declaring them
// 32 makes synthesis build a 32x32 multiplier and a 32-bit compare tree, and it
// pays for that in full — measured at 3 DSP48 blocks, or 1179 LUTs with hard
// multipliers off.
//
// The arithmetic here is character-for-character the same. Only the buses are
// the size of the values they carry, which is what the equivalence check proves.

`timescale 1ns / 1ps
`default_nettype none

module gft_mul_w #(
    parameter integer MANT_W    = 9,    // mantissa field width
    parameter integer OFF_W     = 7,    // exponent-offset width (OFFSET_MAX = 80 fits in 7)
    parameter [31:0]  BIAS       = 40,
    parameter [31:0]  OFFSET_MAX = 80,
    parameter [31:0]  MANT_ONE   = 512
) (
    input  wire [OFF_W-1:0]  a_off,
    input  wire [MANT_W-1:0] a_mant,
    input  wire [OFF_W-1:0]  b_off,
    input  wire [MANT_W-1:0] b_mant,
    output wire [OFF_W-1:0]  out_off,
    output wire [MANT_W-1:0] out_mant
);
  localparam integer FM_W   = MANT_W + 1;        // 1.M, so 10 bits
  localparam integer PROD_W = 2 * FM_W;          // 20 bits, exactly
  localparam integer SUM_W  = OFF_W + 2;         // a_off + b_off + carry

  wire [FM_W-1:0]   full_a = {1'b1, a_mant};
  wire [FM_W-1:0]   full_b = {1'b1, b_mant};
  wire [PROD_W-1:0] prod   = full_a * full_b;

  // (2*MANT_ONE)*MANT_ONE with MANT_ONE a power of two is just a bit position.
  wire carry = prod[PROD_W-1];

  wire [SUM_W-1:0] sum    = {{(SUM_W-OFF_W){1'b0}}, a_off} + {{(SUM_W-OFF_W){1'b0}}, b_off} + {{(SUM_W-1){1'b0}}, carry};
  wire [SUM_W-1:0] result = sum - BIAS[SUM_W-1:0];

  assign out_off = (sum < BIAS[SUM_W-1:0])       ? {OFF_W{1'b0}} :
                   (result >= OFFSET_MAX[SUM_W-1:0]) ? OFFSET_MAX[OFF_W-1:0] : result[OFF_W-1:0];

  // Dividing by a power of two is a shift; subtracting MANT_ONE drops the hidden bit.
  assign out_mant = carry ? prod[PROD_W-2 -: MANT_W]
                          : prod[PROD_W-3 -: MANT_W];

endmodule
`default_nettype wire
