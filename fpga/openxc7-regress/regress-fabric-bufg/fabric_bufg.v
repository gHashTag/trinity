// Two global buffers, one pin-driven and one fabric-driven.
//
// sys_clk comes from an IBUFDS on a clock-capable pin, so try_preplace() finds
// it "based on dedicated routing" the way it always did.
//
// div is produced by a flip-flop. Yosys' clkbufmap promotes it to a BUFG as
// well, and that buffer has no dedicated path from any pin -- it is the one
// that used to abort placement.
//
// Keep this module minimal. Every extra cell is another reason a failure could
// be blamed on something other than the buffer.
module top(input clk_p, input clk_n, output led);
  wire sys_clk;
  IBUFDS ib(.I(clk_p), .IB(clk_n), .O(sys_clk));

  reg div = 1'b0;
  always @(posedge sys_clk) div <= ~div;   // fabric-driven clock

  reg [23:0] c = 24'd0;
  always @(posedge div) c <= c + 1'b1;     // clocked by the fabric clock

  assign led = c[23];
endmodule
