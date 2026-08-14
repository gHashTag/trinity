// Pipelined GF16 four-term dot product.
//
// The combinational gf16_dot4 chains four float multiplies and three float adds
// into one path. Measured on an XC7A200T that path closes at 9.97 MHz, which is
// too slow for the core to be worth licensing — every comparable vendor core
// reaches 100 MHz or more, and does it by pipelining.
//
// The module's own structure hands us the stage boundaries:
//
//   stage 1   four multiplies, in parallel
//   stage 2   two adds, in parallel
//   stage 3   the final add
//
// Latency is therefore exactly 3 cycles, throughput one result per cycle. The
// arithmetic is untouched — the same gf16_mul and gf16_add instances, with
// registers between them — so the results must be bit-identical to the
// combinational version, delayed by three cycles. That is checked, not assumed.

`default_nettype none

module gf16_dot4_p (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] a0, a1, a2, a3,
    input  wire [15:0] b0, b1, b2, b3,
    output reg  [15:0] result
);

  // ── stage 1: the four products ────────────────────────────────────────────
  wire [15:0] p0, p1, p2, p3;
  gf16_mul m0 (.a(a0), .b(b0), .result(p0));
  gf16_mul m1 (.a(a1), .b(b1), .result(p1));
  gf16_mul m2 (.a(a2), .b(b2), .result(p2));
  gf16_mul m3 (.a(a3), .b(b3), .result(p3));

  reg [15:0] p0r, p1r, p2r, p3r;
  always @(posedge clk) begin
    if (!rst_n) begin
      p0r <= 16'h0000; p1r <= 16'h0000; p2r <= 16'h0000; p3r <= 16'h0000;
    end else begin
      p0r <= p0; p1r <= p1; p2r <= p2; p3r <= p3;
    end
  end

  // ── stage 2: pairwise sums ────────────────────────────────────────────────
  wire [15:0] s01, s23;
  gf16_add a01 (.a(p0r), .b(p1r), .result(s01));
  gf16_add a23 (.a(p2r), .b(p3r), .result(s23));

  reg [15:0] s01r, s23r;
  always @(posedge clk) begin
    if (!rst_n) begin
      s01r <= 16'h0000; s23r <= 16'h0000;
    end else begin
      s01r <= s01; s23r <= s23;
    end
  end

  // ── stage 3: the final sum ────────────────────────────────────────────────
  wire [15:0] total;
  gf16_add a_final (.a(s01r), .b(s23r), .result(total));

  always @(posedge clk) begin
    if (!rst_n) result <= 16'h0000;
    else        result <= total;
  end

endmodule
