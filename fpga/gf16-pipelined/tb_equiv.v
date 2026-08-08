// Equivalence check: the pipelined dot product must produce bit-identical
// results to the combinational one, three cycles later.
//
// This is the same discipline the verification service sells. The reference here
// is not a model of what the arithmetic should be — it is the module that already
// exists and is trusted. The claim under test is narrower and exact: pipelining
// changed the timing and nothing else.

`default_nettype none
`timescale 1ns / 1ps

module tb_equiv;

  reg clk = 0, rst_n = 0;
  reg [15:0] a [0:3];
  reg [15:0] b [0:3];

  wire [15:0] comb_result;
  wire [15:0] pipe_result;

  gf16_dot4 u_comb (
      .a0(a[0]), .a1(a[1]), .a2(a[2]), .a3(a[3]),
      .b0(b[0]), .b1(b[1]), .b2(b[2]), .b3(b[3]),
      .result(comb_result)
  );

  gf16_dot4_p u_pipe (
      .clk(clk), .rst_n(rst_n),
      .a0(a[0]), .a1(a[1]), .a2(a[2]), .a3(a[3]),
      .b0(b[0]), .b1(b[1]), .b2(b[2]), .b3(b[3]),
      .result(pipe_result)
  );

  // Delay line: the combinational answer, held for three cycles so it can be
  // compared against the pipeline's output at the moment it emerges.
  reg [15:0] expect_d1, expect_d2, expect_d3;
  always @(posedge clk) begin
    expect_d1 <= comb_result;
    expect_d2 <= expect_d1;
    expect_d3 <= expect_d2;
  end

  integer i, errors, checks;
  reg [31:0] seed;

  always #5 clk = ~clk;

  // A spread of exponents and mantissas, plus the encodings the format treats
  // specially, because those are where a pipeline boundary is most likely to
  // drop something.
  function [15:0] pick(input [31:0] r);
    begin
      case (r[2:0])
        3'd0:    pick = 16'h0000;              // zero
        3'd1:    pick = 16'hFC00;              // special / inf-like
        3'd2:    pick = 16'h7C01;              // special with mantissa
        3'd3:    pick = 16'h3E00;              // unity in this format
        default: pick = r[15:0];
      endcase
    end
  endfunction

  initial begin
    errors = 0; checks = 0; seed = 32'hACE1_2026;
    rst_n = 0;
    repeat (4) @(posedge clk);
    rst_n = 1;

    for (i = 0; i < 60000; i = i + 1) begin
      @(negedge clk);
      seed = {seed[30:0], seed[31] ^ seed[21] ^ seed[1] ^ seed[0]};
      a[0] <= pick(seed);           b[0] <= pick(seed ^ 32'h1111_1111);
      seed = {seed[30:0], seed[31] ^ seed[21] ^ seed[1] ^ seed[0]};
      a[1] <= pick(seed);           b[1] <= pick(seed ^ 32'h2222_2222);
      seed = {seed[30:0], seed[31] ^ seed[21] ^ seed[1] ^ seed[0]};
      a[2] <= pick(seed);           b[2] <= pick(seed ^ 32'h3333_3333);
      seed = {seed[30:0], seed[31] ^ seed[21] ^ seed[1] ^ seed[0]};
      a[3] <= pick(seed);           b[3] <= pick(seed ^ 32'h4444_4444);

      @(posedge clk);
      #1;
      if (i > 6) begin
        checks = checks + 1;
        if (pipe_result !== expect_d3) begin
          errors = errors + 1;
          if (errors <= 15)
            $display("MISMATCH at %0d: pipelined=%h combinational(delayed)=%h", i, pipe_result, expect_d3);
        end
      end
    end

    $display("");
    $display("compared %0d cycles, %0d mismatches", checks, errors);
    if (errors == 0) $display("RESULT: EQUIVALENT");
    else             $display("RESULT: NOT EQUIVALENT");
    $finish;
  end

endmodule
