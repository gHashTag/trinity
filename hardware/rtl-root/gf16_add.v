`default_nettype none

// ═════════════════════════════════════════════════════════════════════════════
// GF16 ADDER — Golden Float 16 Addition
// ═════════════════════════════════════════════════════════════════════════════
//
// GF16 format: [sign:1][exp:6][mant:9] = 16 bits total
// exp:mant = 6:9 = 0.667 ≈ 1/φ (0.618), φ-distance ≈ 0.049
//
// Pipeline stages:
//   Stage 1: Decode sign/exp/mant, align exponents (for addition)
//   Stage 2: Core addition (mantissa add with carry)
//   Stage 3: Normalize + round-to-nearest-even + pack
//
// φ² + 1/φ² = 3 | TRINITY
//
// Reference: src/hslm/intraparietal_sulcus.zig (gf16FromF32, gf16ToF32)

module gf16_add (
    input  wire clk,
    input  wire rst_n,

    // Handshake interface
    input  wire in_valid,
    output wire in_ready,
    input  wire [1:0] in_op,  // 00=ADD, 01=SUB (future), 10=MUL (not used), 11=reserved

    // Operands (GF16 format: [sign:1][exp:6][mant:9])
    input  wire [15:0] in_a,
    input  wire [15:0] in_b,

    // Output handshake
    output reg out_valid,
    input  wire out_ready,
    output reg [15:0] out_y
);

    // ====================================================================
    // CONSTANTS (matching intraparietal_sulcus.zig)
    // ====================================================================
    localparam GF16_EXP_BITS = 6;
    localparam GF16_EXP_BIAS = 31;  // (1 << (6-1)) - 1
    localparam GF16_MAX_EXP = 62;  // (1 << 6) - 2
    localparam GF16_MIN_EXP = 1;

    // ====================================================================
    // DECODE STAGE (Stage 1)
    // ====================================================================
    wire sign_a = in_a[15];
    wire sign_b = in_b[15];
    wire [5:0] exp_a = in_a[14:9];
    wire [5:0] exp_b = in_b[14:9];
    wire [8:0] mant_a = {1'b1, in_a[8:0]};  // Add implicit 1
    wire [8:0] mant_b = {1'b1, in_b[8:0]};

    // Zero detection
    wire is_zero_a = (in_a == 16'h0000);
    wire is_zero_b = (in_b == 16'h0000);
    wire is_result_zero = is_zero_a | is_zero_b;

    // ====================================================================
    // EXPONENT ALIGNMENT (Stage 1 cont.)
    // ====================================================================
    wire [5:0] exp_diff = exp_a - exp_b;  // signed difference
    wire [4:0] shift_a = 0;  // if exp_a >= exp_b, don't shift A
    wire [4:0] shift_b = (exp_diff[5]) ? 5'h1F : exp_diff[4:0];  // Min shift = 31

    // Shift mantissa B right by exp difference
    // Right shift with sign extension
    wire [8:0] mant_b_shifted =
        (shift_b == 5'd0) ? mant_b :
        (shift_b == 5'd1) ? {1'b0, mant_b[8:1]} :
        (shift_b == 5'd2) ? {2'b0, mant_b[8:2]} :
        (shift_b == 5'd3) ? {3'b0, mant_b[8:3]} :
        (shift_b == 5'd4) ? {4'b0, mant_b[8:4]} :
        (shift_b == 5'd5) ? {5'b0, mant_b[8:5]} :
        (shift_b == 5'd6) ? {6'b0, mant_b[8:6]} :
        (shift_b == 5'd7) ? {7'b0, mant_b[8:7]} :
        (shift_b == 5'd8) ? {8'b0, mant_b[8]} :      // 1 shifted out
        9'h000;  // All zeros for shift > 8 (underflow)

    // ====================================================================
    // CORE ADDITION STAGE (Stage 2)
    // ====================================================================
    // Extended mantissa for addition (10 bits + carry)
    wire [9:0] mant_sum = mant_a + mant_b_shifted;

    // Carry out (bit 9)
    wire carry_out = mant_sum[9];

    // ====================================================================
    // NORMALIZATION STAGE (Stage 3)
    // ====================================================================
    // Result exponent (aligned, same as larger exp)
    wire [5:0] exp_aligned = (exp_a >= exp_b) ? exp_a : exp_b;

    // Check if mantissa overflow occurred (carry_out)
    wire mant_overflow = carry_out;

    // Normalized exponent:
    //   If mantissa overflow, shift right and increment exponent
    //   If mantissa underflow (shifted to zero), shift left and decrement exponent
    wire [9:0] mant_add_result = mant_overflow ?
        {1'b0, mant_sum[9:1]} :  // Shift right
        mant_sum[9:0];               // No shift

    wire [5:0] exp_normalized = mant_overflow ?
        exp_aligned + 6'd1 :  // Increment exponent
        exp_aligned;

    // Leading zero count for normalization (left shift if needed)
    wire [3:0] lz_count =
        (mant_add_result[9]) ? 4'd0 :
        (mant_add_result[8]) ? 4'd1 :
        (mant_add_result[7]) ? 4'd2 :
        (mant_add_result[6]) ? 4'd3 :
        (mant_add_result[5]) ? 4'd4 :
        (mant_add_result[4]) ? 4'd5 :
        (mant_add_result[3]) ? 4'd6 :
        (mant_add_result[2]) ? 4'd7 :
        (mant_add_result[1]) ? 4'd8 :
        4'd9;

    // Normalized mantissa (shift left by leading zeros)
    wire [9:0] mant_normalized =
        (lz_count == 4'd0) ? mant_add_result :
        (lz_count == 4'd1) ? {mant_add_result[8:0], 1'b0} :
        (lz_count == 4'd2) ? {mant_add_result[7:0], 2'b0} :
        (lz_count == 4'd3) ? {mant_add_result[6:0], 3'b0} :
        (lz_count == 4'd4) ? {mant_add_result[5:0], 4'b0} :
        (lz_count == 4'd5) ? {mant_add_result[4:0], 5'b0} :
        (lz_count == 4'd6) ? {mant_add_result[3:0], 6'b0} :
        (lz_count == 4'd7) ? {mant_add_result[2:0], 7'b0} :
        (lz_count == 4'd8) ? {mant_add_result[1:0], 8'b0} :
        9'h100;  // Should not happen with proper input

    // Adjusted exponent (decrement for left shift)
    wire [5:0] exp_adjusted = exp_normalized - lz_count;

    // ====================================================================
    // EXPONENT SATURATION
    // ====================================================================
    wire exp_overflow = (exp_adjusted >= GF16_MAX_EXP);
    wire exp_underflow = (exp_adjusted < GF16_MIN_EXP);

    wire [5:0] exp_final =
        exp_overflow ? GF16_MAX_EXP :
        exp_underflow ? 6'd0 :
        exp_adjusted;

    // ====================================================================
    // ROUNDING AND PACKING (Stage 3 cont.)
    // ====================================================================
    // Take 9 bits from normalized mantissa (drop implicit 1)
    // Round to nearest even using bit 9 (first discarded bit)
    wire [8:0] mant_rounded = mant_normalized[8:0];

    // Rounding: add 1 if bit 9 is 1 and (bits 10+ are non-zero OR even lsb)
    wire round_bit = mant_normalized[9];
    wire [4:0] round_remainder = mant_normalized[14:10];

    wire do_round = round_bit & (|round_remainder);
    wire tie_to_even = round_bit & (round_remainder == 5'd0) & (~mant_normalized[0]);
    wire increment = do_round & ~tie_to_even;

    // Rounded mantissa (9 bits)
    wire [8:0] mant_final = mant_rounded + {7'd0, increment};

    // Check for mantissa overflow after rounding
    wire round_overflow = mant_final[8];

    wire [8:0] mant_result_final =
        round_overflow ? {8'd0, 1'b1} :  // Shift right, carry to exp
        mant_final;

    // Final exponent (adjusted for rounding overflow)
    wire [5:0] exp_result =
        round_overflow ? (exp_final + 6'd1) :
        exp_final;

    // Check for final exponent overflow
    wire final_overflow = (exp_result >= GF16_MAX_EXP);
    wire [5:0] exp_result_clamped =
        final_overflow ? GF16_MAX_EXP :
        exp_result;

    // Sign: XOR of input signs (addition)
    wire sign_result = sign_a ^ sign_b;

    // ====================================================================
    // ZERO DETECTION
    // ====================================================================
    // Handle exact zeros and near-zero results
    wire is_near_zero = (exp_result_clamped == 6'd0) & (mant_result_final == 9'd0);
    wire final_zero = is_result_zero | is_near_zero;

    // ====================================================================
    // PIPELINE REGISTERS
    // ====================================================================
    // Stage 1 registers (decode + align)
    reg sign_a_r, sign_b_r;
    reg [5:0] exp_a_r, exp_b_r;
    reg [8:0] mant_a_r, mant_b_r;
    reg [4:0] shift_b_r;
    reg is_result_zero_r;

    // Stage 2 registers (core add)
    reg [9:0] mant_add_r;
    reg carry_out_r;
    reg [5:0] exp_aligned_r;
    reg mant_overflow_r;

    // Stage 3 registers (normalize + round + pack)
    reg [5:0] exp_final_r;
    reg [8:0] mant_final_r;
    reg sign_result_r;
    reg final_zero_r;

    // Valid pipeline
    reg [2:0] valid_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
            sign_a_r <= 1'b0;
            sign_b_r <= 1'b0;
            exp_a_r <= 6'd0;
            exp_b_r <= 6'd0;
            mant_a_r <= 9'd0;
            mant_b_r <= 9'd0;
            shift_b_r <= 5'd0;
            is_result_zero_r <= 1'b0;
            mant_add_r <= 10'd0;
            carry_out_r <= 1'b0;
            exp_aligned_r <= 6'd0;
            mant_overflow_r <= 1'b0;
            exp_final_r <= 6'd0;
            mant_final_r <= 9'd0;
            sign_result_r <= 1'b0;
            final_zero_r <= 1'b0;
            valid_pipe <= 3'd0;
            out_valid <= 1'b0;
            out_y <= 16'h0000;
            in_ready <= 1'b1;
        end else begin
            // Shift pipeline
            valid_pipe <= {valid_pipe[1:0], in_valid};
            in_ready <= out_ready;

            // Stage 1: latch decode
            sign_a_r <= sign_a;
            sign_b_r <= sign_b;
            exp_a_r <= exp_a;
            exp_b_r <= exp_b;
            mant_a_r <= mant_a[8:0];  // Remove implicit 1
            mant_b_r <= mant_b[8:0];
            shift_b_r <= shift_b;
            is_result_zero_r <= is_result_zero;

            // Stage 2: latch add result
            mant_add_r <= mant_sum;
            carry_out_r <= carry_out;
            exp_aligned_r <= exp_aligned;
            mant_overflow_r <= mant_overflow;

            // Stage 3: latch normalize+round+pack result
            exp_final_r <= exp_result_clamped;
            mant_final_r <= mant_result_final;
            sign_result_r <= sign_result;
            final_zero_r <= final_zero;

            // Output
            out_valid <= valid_pipe[2];
            out_y <= final_zero_r ?
                16'h0000 :
                {sign_result_r, exp_final_r, mant_final_r};
        end
    end

endmodule
