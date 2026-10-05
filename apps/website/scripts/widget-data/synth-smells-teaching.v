// Hand-written teaching sample for the synth-smells widget (Trinity S3AI).
// NOT generated from a t27 spec. Every smell below is put here on purpose.
module smelly_teaching (
  input  wire       clk,
  input  wire       rst,
  input  wire [1:0] sel,
  input  wire [3:0] a,
  input  wire [3:0] b,
  input  wire       we,
  input  wire [1:0] wa,
  input  wire [3:0] wd,
  output reg  [3:0] y,
  output wire [3:0] z,
  output wire [3:0] q,
  output wire       w
);
  // Smell 1: a case with no default and no value for sel == 2'b11, so y keeps its
  // old value there: a latch.
  always @* begin
    case (sel)
      2'b00: y = a;
      2'b01: y = b;
      2'b10: y = a & b;
    endcase
  end

  // Smell 2: a wire that is read but nothing drives.
  wire [3:0] forgot;
  assign z = a ^ forgot;

  // Smell 3: two drivers on one wire.
  wire both;
  assign both = a[0];
  assign both = b[0];
  assign w = both;

  // Smell 4: a register file cleared in a reset loop, so it cannot stay a memory.
  reg [3:0] regs [0:3];
  integer i;
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < 4; i = i + 1) regs[i] <= 4'd0;
    end else if (we) begin
      regs[wa] <= wd;
    end
  end
  assign q = regs[sel];
endmodule
