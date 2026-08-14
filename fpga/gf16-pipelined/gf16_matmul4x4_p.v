// Pipelined GF16 4x4 matrix multiplier.
//
// Identical to gf16_matmul4x4 except that each of its sixteen dot products is
// the pipelined variant. Latency 3 cycles, one full 4x4 result per cycle, and
// the arithmetic is untouched — the equivalence of gf16_dot4_p against
// gf16_dot4 is checked bit-exactly in tb_equiv.v.

module gf16_matmul4x4_p (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] a00, a01, a02, a03,
    input  wire [15:0] a10, a11, a12, a13,
    input  wire [15:0] a20, a21, a22, a23,
    input  wire [15:0] a30, a31, a32, a33,
    input  wire [15:0] b00, b01, b02, b03,
    input  wire [15:0] b10, b11, b12, b13,
    input  wire [15:0] b20, b21, b22, b23,
    input  wire [15:0] b30, b31, b32, b33,
    output wire [15:0] c00, c01, c02, c03,
    output wire [15:0] c10, c11, c12, c13,
    output wire [15:0] c20, c21, c22, c23,
    output wire [15:0] c30, c31, c32, c33
);

    gf16_dot4_p dot_r0_c0 (
        .clk(clk), .rst_n(rst_n),
        .a0(a00), .a1(a01), .a2(a02), .a3(a03),
        .b0(b00), .b1(b10), .b2(b20), .b3(b30),
        .result(c00)
    );
    gf16_dot4_p dot_r0_c1 (
        .clk(clk), .rst_n(rst_n),
        .a0(a00), .a1(a01), .a2(a02), .a3(a03),
        .b0(b01), .b1(b11), .b2(b21), .b3(b31),
        .result(c01)
    );
    gf16_dot4_p dot_r0_c2 (
        .clk(clk), .rst_n(rst_n),
        .a0(a00), .a1(a01), .a2(a02), .a3(a03),
        .b0(b02), .b1(b12), .b2(b22), .b3(b32),
        .result(c02)
    );
    gf16_dot4_p dot_r0_c3 (
        .clk(clk), .rst_n(rst_n),
        .a0(a00), .a1(a01), .a2(a02), .a3(a03),
        .b0(b03), .b1(b13), .b2(b23), .b3(b33),
        .result(c03)
    );

    gf16_dot4_p dot_r1_c0 (
        .clk(clk), .rst_n(rst_n),
        .a0(a10), .a1(a11), .a2(a12), .a3(a13),
        .b0(b00), .b1(b10), .b2(b20), .b3(b30),
        .result(c10)
    );
    gf16_dot4_p dot_r1_c1 (
        .clk(clk), .rst_n(rst_n),
        .a0(a10), .a1(a11), .a2(a12), .a3(a13),
        .b0(b01), .b1(b11), .b2(b21), .b3(b31),
        .result(c11)
    );
    gf16_dot4_p dot_r1_c2 (
        .clk(clk), .rst_n(rst_n),
        .a0(a10), .a1(a11), .a2(a12), .a3(a13),
        .b0(b02), .b1(b12), .b2(b22), .b3(b32),
        .result(c12)
    );
    gf16_dot4_p dot_r1_c3 (
        .clk(clk), .rst_n(rst_n),
        .a0(a10), .a1(a11), .a2(a12), .a3(a13),
        .b0(b03), .b1(b13), .b2(b23), .b3(b33),
        .result(c13)
    );

    gf16_dot4_p dot_r2_c0 (
        .clk(clk), .rst_n(rst_n),
        .a0(a20), .a1(a21), .a2(a22), .a3(a23),
        .b0(b00), .b1(b10), .b2(b20), .b3(b30),
        .result(c20)
    );
    gf16_dot4_p dot_r2_c1 (
        .clk(clk), .rst_n(rst_n),
        .a0(a20), .a1(a21), .a2(a22), .a3(a23),
        .b0(b01), .b1(b11), .b2(b21), .b3(b31),
        .result(c21)
    );
    gf16_dot4_p dot_r2_c2 (
        .clk(clk), .rst_n(rst_n),
        .a0(a20), .a1(a21), .a2(a22), .a3(a23),
        .b0(b02), .b1(b12), .b2(b22), .b3(b32),
        .result(c22)
    );
    gf16_dot4_p dot_r2_c3 (
        .clk(clk), .rst_n(rst_n),
        .a0(a20), .a1(a21), .a2(a22), .a3(a23),
        .b0(b03), .b1(b13), .b2(b23), .b3(b33),
        .result(c23)
    );

    gf16_dot4_p dot_r3_c0 (
        .clk(clk), .rst_n(rst_n),
        .a0(a30), .a1(a31), .a2(a32), .a3(a33),
        .b0(b00), .b1(b10), .b2(b20), .b3(b30),
        .result(c30)
    );
    gf16_dot4_p dot_r3_c1 (
        .clk(clk), .rst_n(rst_n),
        .a0(a30), .a1(a31), .a2(a32), .a3(a33),
        .b0(b01), .b1(b11), .b2(b21), .b3(b31),
        .result(c31)
    );
    gf16_dot4_p dot_r3_c2 (
        .clk(clk), .rst_n(rst_n),
        .a0(a30), .a1(a31), .a2(a32), .a3(a33),
        .b0(b02), .b1(b12), .b2(b22), .b3(b32),
        .result(c32)
    );
    gf16_dot4_p dot_r3_c3 (
        .clk(clk), .rst_n(rst_n),
        .a0(a30), .a1(a31), .a2(a32), .a3(a33),
        .b0(b03), .b1(b13), .b2(b23), .b3(b33),
        .result(c33)
    );

endmodule
