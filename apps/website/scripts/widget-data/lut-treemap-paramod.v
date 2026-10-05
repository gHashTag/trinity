// SPDX-License-Identifier: Apache-2.0
// lut-treemap-paramod.v -- a parser fixture for public/widgets/lut-treemap/treemap.js, not a design.
// yosys names a parameterised module "$paramod\leaf\W=s32'...0100" in stat -json, both as the module
// key and as the cell type in its parent's num_cells_by_type; and leaf #(4) is reached by two paths
// (m0 and m1), so its instance count must add both. scripts/widget-data/lut-treemap.mjs runs
//   synth_xilinx -top pmtop; tee -q -o stat.json stat -json
// on this file and checks that treemap.js reads the names as "leaf W=4" / "leaf W=8", counts
// leaf W=4 four times, and lands on yosys's own design total.
module leaf #(parameter W = 4) (input wire clk, input wire [W-1:0] a, b, output reg [W-1:0] y);
  always @(posedge clk) y <= a + b;
endmodule
module mid (input wire clk, input wire [3:0] a, b, output wire [3:0] y);
  wire [3:0] t;
  leaf #(.W(4)) u0 (.clk(clk), .a(a), .b(b), .y(t));
  leaf #(.W(4)) u1 (.clk(clk), .a(t), .b(b), .y(y));
endmodule
module pmtop (input wire clk, input wire [7:0] a, b, output wire [7:0] y, output wire [3:0] z, output wire [3:0] z2);
  leaf #(.W(8)) wide (.clk(clk), .a(a), .b(b), .y(y));
  mid m0 (.clk(clk), .a(a[3:0]), .b(b[3:0]), .y(z));
  mid m1 (.clk(clk), .a(a[7:4]), .b(b[7:4]), .y(z2));
endmodule
