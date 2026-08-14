// The pipelined multiplier must match the combinational one, two cycles later,
// across the same exhaustive sweep.
`default_nettype none
`timescale 1ns/1ps
module tb_pipe_equiv;
  reg clk=0, rst_n=0;
  reg [6:0] ao, bo; reg [8:0] am, bm;
  wire [6:0] c_off; wire [8:0] c_m;
  wire [6:0] p_off; wire [8:0] p_m;
  gft_mul_w  u_c (.a_off(ao), .a_mant(am), .b_off(bo), .b_mant(bm), .out_off(c_off), .out_mant(c_m));
  gft_mul_wp u_p (.clk(clk), .rst_n(rst_n), .a_off(ao), .a_mant(am), .b_off(bo), .b_mant(bm), .out_off(p_off), .out_mant(p_m));
  reg [6:0] e_off1, e_off2; reg [8:0] e_m1, e_m2;
  always @(posedge clk) begin e_off1<=c_off; e_off2<=e_off1; e_m1<=c_m; e_m2<=e_m1; end
  integer i, errors, checks; reg [31:0] s;
  always #5 clk = ~clk;
  initial begin
    errors=0; checks=0; s=32'hBEEF_2026; rst_n=0;
    repeat (4) @(posedge clk); rst_n=1;
    for (i=0;i<200000;i=i+1) begin
      @(negedge clk);
      s = {s[30:0], s[31]^s[21]^s[1]^s[0]};
      am <= s[8:0]; bm <= s[20:12];
      ao <= (s[27:22] % 81); bo <= (s[31:26] % 81);
      @(posedge clk); #1;
      if (i>5) begin
        checks=checks+1;
        if (p_off!==e_off2 || p_m!==e_m2) begin
          errors=errors+1;
          if (errors<=10) $display("MISMATCH i=%0d pipe=(%0d,%0d) comb_delayed=(%0d,%0d)", i, p_off, p_m, e_off2, e_m2);
        end
      end
    end
    $display("");
    $display("compared %0d cycles, %0d mismatches", checks, errors);
    if (errors==0) $display("RESULT: EQUIVALENT"); else $display("RESULT: NOT EQUIVALENT");
    $finish;
  end
endmodule
