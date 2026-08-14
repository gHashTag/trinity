// gft_mul_w at the GF-T32 rung against gft_mul32 — the 64-bit module that exists
// precisely because the 32-bit one cannot hold this product.
`default_nettype none
`timescale 1ns/1ps
module tb32;
  reg [31:0] ao, am, bo, bm;
  wire [31:0] r_off, r_mant;
  gft_mul32 u_ref (.a_off(ao), .a_mant(am), .b_off(bo), .b_mant(bm), .out_off(r_off), .out_mant(r_mant));

  reg [9:0] wao, wbo; reg [24:0] wam, wbm;
  wire [9:0] w_off; wire [24:0] w_mant;
  gft_mul_w #(.MANT_W(25), .OFF_W(10), .BIAS(364), .OFFSET_MAX(728), .MANT_ONE(33554432)) u_w
    (.a_off(wao), .a_mant(wam), .b_off(wbo), .b_mant(wbm), .out_off(w_off), .out_mant(w_mant));

  integer i, errors, checks; reg [63:0] s;
  initial begin
    errors=0; checks=0; s=64'hFEED_FACE_1234_5678;
    for (i=0;i<300000;i=i+1) begin
      s = {s[62:0], s[63]^s[62]^s[60]^s[59]};
      ao = s[9:0] % 729; bo = s[25:16] % 729;
      am = s[56:32]; bm = {s[24:10], s[41:32]};
      wao = ao[9:0]; wbo = bo[9:0]; wam = am[24:0]; wbm = bm[24:0];
      #1; checks=checks+1;
      if (r_off[9:0]!==w_off || r_mant[24:0]!==w_mant) begin
        errors=errors+1;
        if (errors<=6) $display("  MISMATCH: ref=(%0d,%0d) w=(%0d,%0d)", r_off, r_mant, w_off, w_mant);
      end
    end
    $display("  %0d combinations, %0d mismatches -> %s", checks, errors, errors==0?"EQUIVALENT":"NOT EQUIVALENT");
    $finish;
  end
endmodule
