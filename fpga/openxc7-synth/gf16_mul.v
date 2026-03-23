//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`default_nettype none

// ═════════════════════════════════════════════════════════════════════════════
// GF16 MULTIPLIER — Golden Float 16 Multiplication
// ═══════════════════════════════════════════════════════════════════════════
//
// GF16 format: [sign:1][exp:6][mant:9] = 16 bits total
// exp:mant = 6:9 = 0.667 ≈ 1/φ (0.618), φ-distance ≈ 0.049
//
// Implementation: Uses DSP48E1 for 18×18 multiplication (9-bit mantissas)
// Pipeline stages:
//   Stage 1: Decode sign/exp/mant, exponent addition, pre-normalize
//   Stage 2: DSP48E1 multiplication (mant_a × mant_b)
//   Stage 3: Normalization + rounding + packing
//
// DSP48E1 mode: 25×18 multiply (use 18 bits of B, 18 LSB of A)
//
// φ² + 1/φ² = 3 | TRINITY

module gf16_mul (
    input  wire clk,
    input  wire rst_n,

    // Handshake interface
    input  wire in_valid,
    output wire in_ready,
    input  wire [1:0] in_op,  // 00=ADD (not used), 01=MUL

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
    wire [8:0] mant_a = {1'b1, in_a[8:0]};  // 10-bit with implicit 1
    wire [8:0] mant_b = {1'b1, in_b[8:0]};

    // Zero detection
    wire is_zero_a = (in_a == 16'h0000);
    wire is_zero_b = (in_b == 16'h0000);
    wire is_result_zero = is_zero_a | is_zero_b;

    // Sign result (XOR for multiplication)
    wire sign_result = sign_a ^ sign_b;

    // ====================================================================
    // EXPONENT ADDITION (Stage 1 cont.)
    // ====================================================================
    // Product exponent = exp_a + exp_b - bias
    // Normal form: mant_a × mant_b = (1.x × 1.y) = 1.xy
    // So we add exponents and subtract one bias
    wire [6:0] exp_sum_raw = {1'b0, exp_a} + {1'b0, exp_b};
    wire [6:0] exp_product = exp_sum_raw - GF16_EXP_BIAS;

    // ====================================================================
    // DSP48E1 MULTIPLICATION STAGE (Stage 2)
    // ====================================================================
    // Use 18×18 multiplication for mantissas (9-bit × 9-bit = 18-bit)
    // DSP48E1: 25-bit A × 18-bit B → 48-bit P
    // We use mant_a[17:0] (18 bits) and mant_b[17:0] (18 bits)
    // Result is mant_a × mant_b

    // DSP input preparation
    wire [17:0] dsp_a = mant_a;  // 18 bits from 10-bit (truncate LSB)
    wire [17:0] dsp_b = mant_b;  // 18 bits from 10-bit (truncate LSB)

    // DSP multiply result (48 bits)
    wire [47:0] dsp_product;

    // OPMODE for simple multiply: Z*Z + 0
    // OPMODE[4:0] = 00000 for C = Z*Z + 0
    wire [4:0] opmode = 5'b00000;

    // ALUMODE for multiply: dynamic add disabled
    wire [3:0] alumode = 4'b0000;

    // ====================================================================
    // NORMALIZATION STAGE (Stage 3)
    // ====================================================================
    // Extract product mantissa (bits 17:1, because 1.1 × 1.1 ≈ 1.0x)
    // The product is 18 bits: bit 17 is the "carry" from 1.1×1.1=1.01
    // We need to check if we need to normalize

    // Check if bit 17 is set (overflow from implicit 1.0)
    wire mant_overflow_dsp = dsp_product[17];

    // Product mantissa: bits 16:0 if no overflow, 17:1 shifted right if overflow
    wire [17:0] mant_product_raw =
        mant_overflow_dsp ? {1'b0, dsp_product[17:1]} :  // Shift right, increment exp
                           dsp_product[16:0];               // No shift needed

    // Product exponent: adjust for DSP overflow
    wire [6:0] exp_product_adj =
        mant_overflow_dsp ? exp_product + 7'd1 : exp_product;

    // Take 10 bits for mantissa (with implicit 1)
    wire [9:0] mant_product = mant_product_raw[9:0];

    // Normalized mantissa (1.x form)
    // Count leading zeros
    wire [3:0] lz_count =
        (mant_product[9]) ? 4'd0 :
        (mant_product[8]) ? 4'd1 :
        (mant_product[7]) ? 4'd2 :
        (mant_product[6]) ? 4'd3 :
        (mant_product[5]) ? 4'd4 :
        (mant_product[4]) ? 4'd5 :
        (mant_product[3]) ? 4'd6 :
        (mant_product[2]) ? 4'd7 :
        (mant_product[1]) ? 4'd8 :
        4'd9;

    // Normalized mantissa (shift left to 1.x)
    wire [9:0] mant_normalized =
        (lz_count == 4'd0) ? mant_product :
        (lz_count == 4'd1) ? {mant_product[8:0], 1'b0} :
        (lz_count == 4'd2) ? {mant_product[7:0], 2'b0} :
        (lz_count == 4'd3) ? {mant_product[6:0], 3'b0} :
        (lz_count == 4'd4) ? {mant_product[5:0], 4'b0} :
        (lz_count == 4'd5) ? {mant_product[4:0], 5'b0} :
        (lz_count == 4'd6) ? {mant_product[3:0], 6'b0} :
        (lz_count == 4'd7) ? {mant_product[2:0], 7'b0} :
        (lz_count == 4'd8) ? {mant_product[1:0], 8'b0} :
        10'h100;  // Should not happen

    // Adjusted exponent (decrement for left shift)
    wire [6:0] exp_normalized = exp_product_adj - lz_count;

    // ====================================================================
    // EXPONENT SATURATION
    // ====================================================================
    wire exp_overflow = (exp_normalized >= GF16_MAX_EXP);
    wire exp_underflow = (exp_normalized < GF16_MIN_EXP);

    wire [5:0] exp_final =
        exp_overflow ? GF16_MAX_EXP :
        exp_underflow ? 6'd0 :
        exp_normalized;

    // ====================================================================
    // ROUNDING AND PACKING (Stage 3 cont.)
    // ====================================================================
    // Drop implicit 1, take 9 bits
    wire [8:0] mant_rounded = mant_normalized[8:0];

    // Rounding: round to nearest even
    // Check bit 9 (first discarded)
    wire round_bit = mant_normalized[9];
    wire [4:0] round_remainder = mant_normalized[14:10];

    wire do_round = round_bit & (|round_remainder);
    wire tie_to_even = round_bit & (round_remainder == 5'd0) & (~mant_normalized[0]);
    wire increment = do_round & ~tie_to_even;

    // Rounded mantissa
    wire [8:0] mant_inc = mant_rounded + {7'd0, increment};

    // Check for overflow after rounding
    wire round_overflow = mant_inc[8];

    wire [8:0] mant_result =
        round_overflow ? {8'd0, 1'b1} :  // Shift right, carry to exp
        mant_inc;

    // Final exponent (adjusted for rounding overflow)
    wire [5:0] exp_result =
        round_overflow ? (exp_final + 6'd1) :
        exp_final;

    // Check for final overflow
    wire final_overflow = (exp_result >= GF16_MAX_EXP);
    wire [5:0] exp_result_clamped =
        final_overflow ? GF16_MAX_EXP :
        exp_result;

    // ====================================================================
    // ZERO DETECTION
    // ====================================================================
    wire is_near_zero = (exp_result_clamped == 6'd0) & (mant_result == 9'd0);
    wire final_zero = is_result_zero | is_near_zero;

    // ====================================================================
    // PIPELINE REGISTERS
    // ====================================================================
    // Stage 1 registers (decode)
    reg sign_result_r;
    reg [5:0] exp_product_r;
    reg [17:0] mant_a_r, mant_b_r;
    reg is_result_zero_r;

    // Stage 2 registers (DSP multiply)
    reg [47:0] dsp_product_r;
    reg mant_overflow_dsp_r;

    // Stage 3 registers (normalize + round + pack)
    reg [5:0] exp_final_r;
    reg [8:0] mant_final_r;
    reg final_zero_r;

    // Valid pipeline
    reg [2:0] valid_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
            sign_result_r <= 1'b0;
            exp_product_r <= 6'd0;
            mant_a_r <= 10'd0;
            mant_b_r <= 10'd0;
            is_result_zero_r <= 1'b0;
            dsp_product_r <= 48'd0;
            mant_overflow_dsp_r <= 1'b0;
            exp_final_r <= 6'd0;
            mant_final_r <= 9'd0;
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
            sign_result_r <= sign_result;
            exp_product_r <= exp_product;
            mant_a_r <= mant_a;
            mant_b_r <= mant_b;
            is_result_zero_r <= is_result_zero;

            // Stage 2: latch DSP result
            dsp_product_r <= dsp_product;
            mant_overflow_dsp_r <= mant_overflow_dsp;

            // Stage 3: latch normalize+round+pack result
            exp_final_r <= exp_result_clamped;
            mant_final_r <= mant_result;
            final_zero_r <= final_zero;

            // Output
            out_valid <= valid_pipe[2];
            out_y <= final_zero_r ?
                16'h0000 :
                {sign_result_r, exp_final_r, mant_final_r};
        end
    end

    // ====================================================================
    // DSP48E1 INSTANTIATION
    // ====================================================================
    DSP48E1 #(
        .ALUMODE_DETECT("ALUMODE"),
        .AUTORESET_PATDET("NO_RESET"),
        .A_INPUT("DIRECT"),
        .B_INPUT("DIRECT"),
        .CARRYIN_SEL("OPMODE5"),
        .CARRYINREG(0),
        .CARRYOUTREG(0),
        .CLK_INVERTED(1'b0),
        .DREG(0),
        .DSP48E1_ONLY(1'b0),
        .IS_ALUMODE_INVERTED(4'b0000),
        .IS_CARRYIN_INVERTED(1'b0),
        .IS_CEA1_INVERTED(1'b0),
        .IS_CEA2_INVERTED(1'b0),
        .IS_CEB1_INVERTED(1'b0),
        .IS_CEB2_INVERTED(1'b0),
        .IS_CEC_INVERTED(1'b0),
        .IS_CED_INVERTED(1'b0),
        .IS_CEP_INVERTED(1'b0),
        .IS_INMODE_INVERTED(2'b00),
        .IS_OPMODE_INVERTED(5'b00000),
        .IS_P_INVERTED(1'b0),
        .IS_RSTA_INVERTED(1'b0),
        .IS_RSTB_INVERTED(1'b0),
        .IS_RSTC_INVERTED(1'b0),
        .IS_RSTD_INVERTED(1'b0),
        .IS_RSTP_INVERTED(1'b0),
        .MASK(48'h3FFFFFFFFFFFF),
        .MREG(0),
        .OPMODESEL(1'b0),
        .PATTERN_DETECT(48'h000000000000),
        .PREG(0),
        .SEL_MASK("MASK"),
        .SEL_PATTERN("PATTERN"),
        .USE_DPORT("TRUE"),
        .USE_MULT("MULTIPLY"),
        .USE_PATTERN_DETECT("NO_PATDET"),
        .USE_SIMD("ONE48")
    ) dsp (
        .CLK(clk),
        .RST(~rst_n),
        .A({7'b0, mant_a_r}),        // 25 bits (use lower 18 for multiply)
        .B(mant_b_r),                // 18 bits
        .C(48'b0),
        .D(48'b0),
        .ALUMODE(alumode),
        .CARRYIN(1'b0),
        .CARRYOUT(),
        .INMODE(2'b00),
        .OPMODE(opmode),
        .P(dsp_product),
        .PATTERNBDETECT(),
        .UNDERFLOW(),
        .OVERFLOW(),
        .CEA1(1'b0),
        .CEA2(1'b0),
        .CEB1(1'b0),
        .CEB2(1'b0),
        .CEC(1'b0),
        .CED(1'b0),
        .CEP(1'b0),
        .RSTA(~rst_n),
        .RSTB(~rst_n),
        .RSTC(~rst_n),
        .RSTD(~rst_n),
        .RSTP(~rst_n),
        .CARRYCASCIN(),
        .CARRYCASCOUT(),
        .MULTSIGNIN(),
        .MULTSIGNOUT()
    );

endmodule
