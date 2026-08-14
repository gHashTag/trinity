// Equivalence at one rung of the ladder: the width-corrected multiplier against
// the original, with both given the same rung parameters. Mantissa space swept in
// full where it is small enough, sampled densely where it is not.
`default_nettype none
`timescale 1ns/1ps
module tb_rung #(
    parameter integer MANT_W = 9, parameter integer OFF_W = 7,
    parameter [31:0] BIAS = 40, parameter [31:0] OFFSET_MAX = 80, parameter [63:0] MANT_ONE = 512,
    parameter integer MSTEP = 1
) ();
  reg [31:0] ao32, am32, bo32, bm32;
  wire [31:0] ro32, rm32;
  gft_mul #(.BIAS(BIAS), .OFFSET_MAX(OFFSET_MAX), .MANT_ONE(MANT_ONE[31:0])) u_ref
    (.a_off(ao32), .a_mant(am32), .b_off(bo32), .b_mant(bm32), .out_off(ro32), .out_mant(rm32));

  reg [OFF_W-1:0] ao, bo; reg [MANT_W-1:0] am, bm;
  wire [OFF_W-1:0] ro; wire [MANT_W-1:0] rm;
  gft_mul_w #(.MANT_W(MANT_W), .OFF_W(OFF_W), .BIAS(BIAS), .OFFSET_MAX(OFFSET_MAX), .MANT_ONE(MANT_ONE[31:0])) u_w
    (.a_off(ao), .a_mant(am), .b_off(bo), .b_mant(bm), .out_off(ro), .out_mant(rm));

  integer a_, b_, ai, bi, errors, checks;
  localparam integer MMAX = (1 << MANT_W);

  task cmp(input integer x, input integer y, input integer p, input integer q);
    begin
      ao32=x; bo32=y; am32=p; bm32=q;
      ao=x[OFF_W-1:0]; bo=y[OFF_W-1:0]; am=p[MANT_W-1:0]; bm=q[MANT_W-1:0];
      #1; checks=checks+1;
      if (ro32[OFF_W-1:0]!==ro || rm32[MANT_W-1:0]!==rm) begin
        errors=errors+1;
        if (errors<=8) $display("  MISMATCH off=(%0d,%0d) mant=(%0d,%0d): ref=(%0d,%0d) w=(%0d,%0d)", x,y,p,q, ro32,rm32, ro,rm);
      end
    end
  endtask

  initial begin
    errors=0; checks=0;
    for (a_=0; a_<=OFFSET_MAX; a_=a_+(OFFSET_MAX/4>0?OFFSET_MAX/4:1))
      for (b_=0; b_<=OFFSET_MAX; b_=b_+(OFFSET_MAX/4>0?OFFSET_MAX/4:1))
        for (ai=0; ai<MMAX; ai=ai+MSTEP)
          for (bi=0; bi<MMAX; bi=bi+(MSTEP*8>0?MSTEP*8:1))
            cmp(a_, b_, ai, bi);
    for (ai=0; ai<MMAX; ai=ai+(MMAX/2>0?MMAX/2:1))
      for (bi=0; bi<MMAX; bi=bi+(MMAX/2>0?MMAX/2:1))
        for (a_=0; a_<=OFFSET_MAX; a_=a_+1)
          for (b_=0; b_<=OFFSET_MAX; b_=b_+1)
            cmp(a_, b_, ai, bi);
    $display("  %0d combinations, %0d mismatches -> %s", checks, errors, errors==0 ? "EQUIVALENT" : "NOT EQUIVALENT");
    $finish;
  end
endmodule
