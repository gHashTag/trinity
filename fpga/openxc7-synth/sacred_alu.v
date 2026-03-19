`default_nettype none

// ═════════════════════════════════════════════════════════════════════════
// SACRED ALU — Unified GF16/TF3-9 Arithmetic Unit
// ═════════════════════════════════════════════════════════════════════════
//
// Trinity Sacred Formats on FPGA Level 6 (RTL)
//
// GF16 (Golden Float 16): exp:mant = 6:9 = 0.667, φ-distance = 0.049
// TF3-9 (Ternary Float 9): exp:mant = 3:5 = 0.6, φ-distance = 0.018
//
// Operations:
//   MODE_GF16_ADD  (2'b00): GF16 addition
//   MODE_GF16_MUL  (2'b01): GF16 multiplication (DSP48E1)
//   MODE_TF3_ADD   (2'b10): TF3-9 ternary addition
//   MODE_TF3_DOT   (2'b11): TF3-9 dot product
//
// φ² + 1/φ² = 3 | TRINITY

module sacred_alu (
    input  wire clk,
    input  wire rst_n,

    // Handshake interface
    input  wire in_valid,
    output wire in_ready,
    input  wire [1:0] mode,  // Operation mode selector

    // 32-bit operand bus (interpreted per mode)
    //   GF16: [15:0] = GF16 value, [31:16] = don't care
    //   TF3:  [17:0] = TF3-9 value, [31:18] = don't care
    input  wire [31:0] in_a,
    input  wire [31:0] in_b,

    // Output handshake
    output reg out_valid,
    input  wire out_ready,
    output reg [31:0] out_y  // 32-bit result (GF16 uses [15:0], TF3 uses [17:0])
);

    // ====================================================================
    // MODE DEFINITIONS
    // ====================================================================
    localparam MODE_GF16_ADD = 2'b00;
    localparam MODE_GF16_MUL = 2'b01;
    localparam MODE_TF3_ADD  = 2'b10;
    localparam MODE_TF3_DOT  = 2'b11;

    // ====================================================================
    // MODE DECODE
    // ====================================================================
    wire is_gf16_add = (mode == MODE_GF16_ADD);
    wire is_gf16_mul = (mode == MODE_GF16_MUL);
    wire is_tf3_add = (mode == MODE_TF3_ADD);
    wire is_tf3_dot = (mode == MODE_TF3_DOT);

    // Operand extraction
    wire [15:0] gf16_a = in_a[15:0];
    wire [15:0] gf16_b = in_b[15:0];
    wire [17:0] tf3_a = in_a[17:0];
    wire [17:0] tf3_b = in_b[17:0];

    // ====================================================================
    // GF16 ALU INSTANTIATION
    // ====================================================================
    wire gf16_ready;
    wire gf16_valid;
    wire [1:0] gf16_op;
    wire [15:0] gf16_out;

    // GF16 uses OP_ADD for both ADD and MUL internally
    assign gf16_op = is_gf16_mul ? 2'b01 : 2'b00;
    assign in_ready = gf16_ready;

    gf16_alu #(
        .OP_ADD(2'b00),
        .OP_MUL(2'b01)
    ) gf16_unit (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid & is_gf16_add | is_gf16_mul),
        .in_ready(gf16_ready),
        .in_op(gf16_op),
        .in_a(gf16_a),
        .in_b(gf16_b),
        .out_valid(gf16_valid),
        .out_ready(out_ready),
        .out_y(gf16_out)
    );

    // ====================================================================
    // TF3-9 ADDER INSTANTIATION
    // ====================================================================
    wire tf3_add_ready;
    wire tf3_add_valid;
    wire [17:0] tf3_add_out;

    tf3_add tf3_adder (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid & is_tf3_add),
        .in_ready(tf3_add_ready),
        .in_op(2'b00),
        .in_a(tf3_a),
        .in_b(tf3_b),
        .out_valid(tf3_add_valid),
        .out_ready(out_ready),
        .out_y(tf3_add_out)
    );

    // ====================================================================
    // TF3-9 DOT PRODUCT INSTANTIATION
    // ====================================================================
    wire tf3_dot_ready;
    wire tf3_dot_valid;
    wire [17:0] tf3_dot_out;
    wire [31:0] tf3_dot_acc;  // Wider accumulator

    // Use N=16 for dot product
    tf3_dot #(
        .N(16),
        .ACC_WIDTH(32)
    ) tf3_dotter (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid & is_tf3_dot),
        .in_ready(tf3_dot_ready),
        .in_op(2'b01),
        .vec_a(tf3_a),
        .vec_b(tf3_b),
        .out_valid(tf3_dot_valid),
        .out_ready(out_ready),
        .out_y(tf3_dot_out),
        .acc_out(tf3_dot_acc[31:0])
    );

    // ====================================================================
    // OUTPUT MULTIPLEXING
    // ====================================================================
    // Select output based on mode
    wire [31:0] result_mux =
        is_gf16_add | is_gf16_mul ? {16'd0, gf16_out} :
        is_tf3_add ? {14'd0, tf3_add_out} :
        is_tf3_dot ? {14'd0, tf3_dot_out} :
        32'd0;  // Should not happen

    // Valid signal MUX
    wire result_valid =
        is_gf16_add ? gf16_valid :
        is_gf16_mul ? gf16_valid :
        is_tf3_add ? tf3_add_valid :
        is_tf3_dot ? tf3_dot_valid :
        1'b0;

    // ====================================================================
    // OUTPUT REGISTERS
    // ====================================================================
    reg [31:0] out_y_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_y_reg <= 32'd0;
            out_valid <= 1'b0;
        end else begin
            out_y_reg <= result_mux;
            out_valid <= result_valid;
        end
    end

    assign out_y = out_y_reg;

endmodule
