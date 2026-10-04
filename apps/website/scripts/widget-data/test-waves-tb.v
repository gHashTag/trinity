// SPDX-License-Identifier: Apache-2.0
// test-waves-tb.v -- testbench for the test-waves widget (apps/website/public/widgets/test-waves/).
//
// Drives the Verilog that t27_compiler.wasm generates from
// public/t27/files/specs/ternary/stream_ternary_mac.t27 (module StreamTernaryMac) with the
// spec's own test vectors. scripts/widget-data/test-waves.mjs reads them from the spec's `test`
// blocks (assert_eq(dot27(a, b), d)) and writes vectors.hex beside this file's copy; nothing here
// is a number of its own.
//
// Each vector is streamed for one clock with en = 1; the module adds dot27(a, b) to acc, so after
// edge i acc must equal the running sum of the first i expected dot products. Two more checks
// read what the generated RTL says it does and the spec's prose promises: a clock with en = 0
// leaves acc alone, and rst_n low clears it at once (the reset is asynchronous).
//
// Output, one line per check, parsed by test-waves.mjs:
//   CHECK <time_ns> <id> <pass|fail> <acc> <expected>
// id 0..N-1 is the spec test of that index; 100 is the en-low hold; 101 is the reset.
`timescale 1ns / 1ps
`default_nettype none

module tb;
  localparam N_MAX = 16;
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg en = 1'b0;
  reg [63:0] a = 64'd0;
  reg [63:0] b = 64'd0;
  wire ready;
  wire signed [31:0] acc;
  reg signed [31:0] expected = 32'sd0;

  reg [63:0] va [0:N_MAX-1];
  reg [63:0] vb [0:N_MAX-1];
  reg [31:0] vd [0:N_MAX-1];
  integer n;
  integer i;
  integer errors;

  StreamTernaryMac dut (
    .clk(clk), .rst_n(rst_n), .en(en), .a(a), .b(b), .ready(ready), .acc(acc)
  );

  always #5 clk = ~clk;

  task check(input integer id);
    begin
      if (acc === expected)
        $display("CHECK %0d %0d pass %0d %0d", $time, id, acc, expected);
      else begin
        errors = errors + 1;
        $display("CHECK %0d %0d fail %0d %0d", $time, id, acc, expected);
      end
    end
  endtask

  initial begin
    errors = 0;
    if (!$value$plusargs("N=%d", n)) n = 0;
    if (n < 1 || n > N_MAX) begin
      $display("FATAL bad vector count %0d", n);
      $finish;
    end
    $readmemh("vectors_a.hex", va, 0, n - 1);
    $readmemh("vectors_b.hex", vb, 0, n - 1);
    $readmemh("vectors_d.hex", vd, 0, n - 1);
    $dumpfile("waves.vcd");
    $dumpvars(0, clk, rst_n, en, a, b, ready, acc, expected);

    // reset for two clocks, then one idle clock with en low
    repeat (2) @(negedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // one spec vector per clock
    for (i = 0; i < n; i = i + 1) begin
      a = va[i];
      b = vb[i];
      en = 1'b1;
      @(posedge clk);
      expected = expected + $signed(vd[i]);
      #1 check(i);
      @(negedge clk);
    end

    // en low: a vector whose dot product is not zero must not reach acc
    a = va[0];
    b = vb[0];
    en = 1'b0;
    @(posedge clk);
    #1 check(100);
    @(negedge clk);

    // asynchronous reset clears acc without waiting for a clock edge
    #2 rst_n = 1'b0;
    expected = 32'sd0;
    #1 check(101);
    @(negedge clk);
    rst_n = 1'b1;
    a = 64'd0;
    b = 64'd0;
    @(negedge clk);
    @(negedge clk);
    $display("DONE errors=%0d", errors);
    $finish;
  end
endmodule
