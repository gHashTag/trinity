//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════
// GF16 ALU — Golden Float 16 Arithmetic Unit
// ═══════════════════════════════════════════════════════════════════════════
//
// GF16 format: [sign:1][exp:6][mant:9] = 16 bits total
// exp:mant = 6:9 = 0.667 ≈ 1/φ (0.618), φ-distance ≈ 0.049
//
// Operations:
//   OP_ADD (2'b00): Addition with exponent alignment
//   OP_MUL (2'b01): Multiplication using DSP48E1
//
// Pipeline: 3 stages minimum
//
// φ² + 1/φ² = 3 | TRINITY

module gf16_alu #(
    parameter OP_ADD = 2'b00,
    parameter OP_MUL = 2'b01
) (
    input  wire clk,
    input  wire rst_n,

    // Handshake interface
    input  wire in_valid,
    output wire in_ready,
    input  wire [1:0] in_op,
    input  wire [15:0] in_a,
    input  wire [15:0] in_b,

    output reg out_valid,
    input  wire out_ready,
    output reg [15:0] out_y
);

    // ====================================================================
    // CONSTANTS
    // ====================================================================
    localparam GF16_EXP_BITS = 6;
    localparam GF16_EXP_BIAS = 31;
    localparam GF16_MAX_EXP = 62;
    localparam GF16_MIN_EXP = 1;

    // ====================================================================
    // DECODE
    // ====================================================================
    wire sign_a = in_a[15];
    wire sign_b = in_b[15];
    wire [5:0] exp_a = in_a[14:9];
    wire [5:0] exp_b = in_b[14:9];
    wire [8:0] mant_a = {1'b1, in_a[8:0]};
    wire [8:0] mant_b = {1'b1, in_b[8:0]};

    wire is_zero_a = (in_a == 16'h0000);
    wire is_zero_b = (in_b == 16'h0000);
    wire is_result_zero = is_zero_a | is_zero_b;

    // ====================================================================
    // OPERATION MUX
    // ====================================================================
    wire is_add = (in_op == OP_ADD);
    wire is_mul = (in_op == OP_MUL);

    // Sign calculation
    wire sign_add = sign_a ^ sign_b;  // Addition: XOR
    wire sign_mul = sign_a ^ sign_b;  // Multiplication: XOR

    wire sign_result = is_add ? sign_add : sign_mul;

    // ====================================================================
    // ADDITION PATH
    // ====================================================================
    wire [5:0] exp_diff = exp_a - exp_b;
    wire [4:0] shift_b = (exp_diff[5]) ? 5'h1F : exp_diff[4:0];

    // Shift mantissa B right
    wire [8:0] mant_b_shifted =
        (shift_b == 5'd0) ? mant_b :
        (shift_b == 5'd1) ? {1'b0, mant_b[8:1]} :
        (shift_b == 5'd2) ? {2'b0, mant_b[8:2]} :
        (shift_b == 5'd3) ? {3'b0, mant_b[8:3]} :
        (shift_b == 5'd4) ? {4'b0, mant_b[8:4]} :
        (shift_b == 5'd5) ? {5'b0, mant_b[8:5]} :
        (shift_b == 5'd6) ? {6'b0, mant_b[8:6]} :
        (shift_b == 5'd7) ? {7'b0, mant_b[8:7]} :
        (shift_b == 5'd8) ? {8'b0, mant_b[8]} :
        9'h000;

    wire [5:0] exp_aligned = (exp_a >= exp_b) ? exp_a : exp_b;

    wire [9:0] mant_sum = mant_a + mant_b_shifted;
    wire carry_out = mant_sum[9];

    wire mant_overflow = carry_out;
    wire [9:0] mant_add_result = mant_overflow ? {1'b0, mant_sum[9:1]} : mant_sum[9:0];
    wire [5:0] exp_add_norm = mant_overflow ? (exp_aligned + 6'd1) : exp_aligned;

    // ====================================================================
    // MULTIPLICATION PATH (using simplified DSP48E1 wrapper)
    // ====================================================================
    // For now, use LUT-based multiply (to be replaced with DSP48E1)
    wire [17:0] mul_mant_a = mant_a;
    wire [17:0] mul_mant_b = mant_b;
    wire [17:0] mul_product_raw = mul_mant_a * mul_mant_b;

    wire mul_overflow = mul_product_raw[17];
    wire [17:0] mul_product = mul_overflow ? {1'b0, mul_product_raw[17:1]} : mul_product_raw[16:0];
    wire [9:0] mul_mant = mul_product[9:0];

    wire [6:0] exp_sum = {1'b0, exp_a} + {1'b0, exp_b};
    wire [6:0] exp_mul_product = exp_sum - GF16_EXP_BIAS;
    wire [6:0] exp_mul_adj = mul_overflow ? (exp_mul_product + 7'd1) : exp_mul_product;

    // ====================================================================
    // COMMON NORMALIZATION
    // ====================================================================
    wire [9:0] mant_raw = is_add ? mant_add_result : mul_mant;
    wire [5:0] exp_raw = is_add ? exp_add_norm : exp_mul_adj;

    // Leading zero count
    wire [3:0] lz_count =
        (mant_raw[9]) ? 4'd0 :
        (mant_raw[8]) ? 4'd1 :
        (mant_raw[7]) ? 4'd2 :
        (mant_raw[6]) ? 4'd3 :
        (mant_raw[5]) ? 4'd4 :
        (mant_raw[4]) ? 4'd5 :
        (mant_raw[3]) ? 4'd6 :
        (mant_raw[2]) ? 4'd7 :
        (mant_raw[1]) ? 4'd8 :
        4'd9;

    wire [9:0] mant_normalized =
        (lz_count == 4'd0) ? mant_raw :
        (lz_count == 4'd1) ? {mant_raw[8:0], 1'b0} :
        (lz_count == 4'd2) ? {mant_raw[7:0], 2'b0} :
        (lz_count == 4'd3) ? {mant_raw[6:0], 3'b0} :
        (lz_count == 4'd4) ? {mant_raw[5:0], 4'b0} :
        (lz_count == 4'd5) ? {mant_raw[4:0], 5'b0} :
        (lz_count == 4'd6) ? {mant_raw[3:0], 6'b0} :
        (lz_count == 4'd7) ? {mant_raw[2:0], 7'b0} :
        (lz_count == 4'd8) ? {mant_raw[1:0], 8'b0} :
        10'h100;

    wire [5:0] exp_normalized = exp_raw - lz_count;

    // Saturation
    wire exp_overflow = (exp_normalized >= GF16_MAX_EXP);
    wire exp_underflow = (exp_normalized < GF16_MIN_EXP);

    wire [5:0] exp_final =
        exp_overflow ? GF16_MAX_EXP :
        exp_underflow ? 6'd0 :
        exp_normalized;

    // Rounding
    wire [8:0] mant_rounded = mant_normalized[8:0];
    wire round_bit = mant_normalized[9];
    wire [4:0] round_remainder = mant_normalized[14:10];

    wire do_round = round_bit & (|round_remainder);
    wire tie_to_even = round_bit & (round_remainder == 5'd0) & (~mant_normalized[0]);
    wire increment = do_round & ~tie_to_even;

    wire [8:0] mant_inc = mant_rounded + {7'd0, increment};
    wire round_overflow = mant_inc[8];
    wire [8:0] mant_result = round_overflow ? {8'd0, 1'b1} : mant_inc;

    wire [5:0] exp_result =
        round_overflow ? (exp_final + 6'd1) :
        exp_final;

    wire final_overflow = (exp_result >= GF16_MAX_EXP);
    wire [5:0] exp_result_clamped =
        final_overflow ? GF16_MAX_EXP :
        exp_result;

    wire is_near_zero = (exp_result_clamped == 6'd0) & (mant_result == 9'd0);
    wire final_zero = is_result_zero | is_near_zero;

    // ====================================================================
    // PIPELINE
    // ====================================================================
    reg [5:0] exp_final_r;
    reg [8:0] mant_final_r;
    reg sign_result_r;
    reg final_zero_r;
    reg [1:0] valid_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exp_final_r <= 6'd0;
            mant_final_r <= 9'd0;
            sign_result_r <= 1'b0;
            final_zero_r <= 1'b0;
            valid_pipe <= 2'd0;
            out_valid <= 1'b0;
            out_y <= 16'h0000;
            in_ready <= 1'b1;
        end else begin
            valid_pipe <= {valid_pipe[0], in_valid};
            in_ready <= out_ready;

            exp_final_r <= exp_result_clamped;
            mant_final_r <= mant_result;
            sign_result_r <= sign_result;
            final_zero_r <= final_zero;

            out_valid <= valid_pipe[1];
            out_y <= final_zero_r ?
                16'h0000 :
                {sign_result_r, exp_final_r, mant_final_r};
        end
    end

endmodule
