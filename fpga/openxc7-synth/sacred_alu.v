// @origin(spec:sacred_alu.tri) @regen(manual-impl)
// Sacred ALU Wrapper — Unified GF16/TF3 Arithmetic Unit
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

`default_nettype none
`timescale 1ns / 1ps

module sacred_alu (
    input  wire clk,
    input  wire rst,          // Active HIGH reset (matches submodules)

    // Handshake interface
    input  wire in_valid,
    output wire in_ready,
    input  wire [1:0] mode,   // Operation mode selector

    // Unified operand bus (32-bit for flexibility)
    //   GF16: [14:0] = GF16 value (sign + exp:mant)
    //   TF3:  [17:0] = TF3-9 value (sign_trit + exp_trits:mant_trits)
    input  wire [31:0] in_a,
    input  wire [31:0] in_b,
    input  wire [7:0]  tf3_dot_len,  // N for TF3 dot product

    // Output handshake
    output wire out_valid,
    output wire [31:0] out_y,  // Result (GF16 in [14:0], TF3 in [17:0])
    input  wire out_ready
);

    // ========================================================================
    // MODE DEFINITIONS
    // ========================================================================
    localparam MODE_GF16_ADD = 2'b00;
    localparam MODE_GF16_MUL = 2'b01;
    localparam MODE_TF3_ADD  = 2'b10;
    localparam MODE_TF3_DOT  = 2'b11;

    // ========================================================================
    // MODE DECODE
    // ========================================================================
    wire is_gf16_add = (mode == MODE_GF16_ADD);
    wire is_gf16_mul = (mode == MODE_GF16_MUL);
    wire is_gf16_op  = is_gf16_add | is_gf16_mul;
    wire is_tf3_op   = !is_gf16_op;

    // Operand extraction
    wire [14:0] gf16_a = in_a[14:0];
    wire [14:0] gf16_b = in_b[14:0];
    wire [17:0] tf3_a  = in_a[17:0];
    wire [17:0] tf3_b  = in_b[17:0];

    // ========================================================================
    // GF16 ADDER INSTANCE (Phase 1)
    // ========================================================================
    wire        gf16_add_ready;
    wire        gf16_add_valid;
    wire [14:0] gf16_add_out;

    gf16_adder gf16_adder_inst (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid & is_gf16_add),
        .in_a(gf16_a),
        .in_b(gf16_b),
        .in_ready(gf16_add_ready),
        .out_valid(gf16_add_valid),
        .out_y(gf16_add_out),
        .out_ready(out_ready)
    );

    // ========================================================================
    // GF16 MULTIPLIER INSTANCE (Phase 2)
    // ========================================================================
    wire        gf16_mul_ready;
    wire        gf16_mul_valid;
    wire [14:0] gf16_mul_out;

    gf16_multiplier gf16_multiplier_inst (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid & is_gf16_mul),
        .in_a(gf16_a),
        .in_b(gf16_b),
        .in_ready(gf16_mul_ready),
        .out_valid(gf16_mul_valid),
        .out_y(gf16_mul_out),
        .out_ready(out_ready)
    );

    // ========================================================================
    // TF3 ALU INSTANCE (Phase 3)
    // ========================================================================
    wire        tf3_ready;
    wire        tf3_valid;
    wire [17:0] tf3_out;

    // Map mode to TF3 ALU mode (00=add, 01=dot)
    wire [1:0] tf3_mode = {1'b0, mode[0]};  // TF3_ADD=00, TF3_DOT=01

    tf3_alu tf3_alu_inst (
        .clk(clk),
        .rst(rst),
        .mode(tf3_mode),
        .in_valid(in_valid & is_tf3_op),
        .in_a(tf3_a),
        .in_b(tf3_b),
        .dot_len(tf3_dot_len),
        .in_ready(tf3_ready),
        .out_valid(tf3_valid),
        .out_y(tf3_out),
        .out_ready(out_ready)
    );

    // ========================================================================
    // OUTPUT MULTIPLEXING
    // ========================================================================
    // Select output based on mode
    wire [31:0] gf16_add_result = {17'd0, gf16_add_out};
    wire [31:0] gf16_mul_result = {17'd0, gf16_mul_out};
    wire [31:0] tf3_result      = {14'd0, tf3_out};

    wire [31:0] result_mux =
        is_gf16_add ? gf16_add_result :
        is_gf16_mul ? gf16_mul_result :
        tf3_result;

    // Valid signal MUX
    wire result_valid =
        is_gf16_add ? gf16_add_valid :
        is_gf16_mul ? gf16_mul_valid :
        tf3_valid;

    // Ready signal MUX
    wire result_ready =
        is_gf16_add ? gf16_add_ready :
        is_gf16_mul ? gf16_mul_ready :
        tf3_ready;

    assign in_ready = result_ready;

    // ========================================================================
    // OUTPUT REGISTERS
    // ========================================================================
    reg [31:0] out_y_reg;
    reg        out_valid_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_y_reg     <= 32'd0;
            out_valid_reg <= 1'b0;
        end else begin
            // Capture result when valid and output is ready to accept
            if (result_valid && out_ready) begin
                out_y_reg     <= result_mux;
                out_valid_reg <= 1'b1;
            end else if (out_ready) begin
                out_valid_reg <= 1'b0;
            end
        end
    end

    assign out_valid = out_valid_reg;
    assign out_y     = out_y_reg;

endmodule
