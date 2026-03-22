// @origin(spec:gf16_multiplier.tri) @regen(manual-impl)
// GF16 Multiplier — Golden Float 16 Multiplication Unit
//
// GF16 format (15 bits + sign):
//   [14]    - sign bit (1 = negative)
//   [13:8]  - exponent (6 bits, bias TBD)
//   [7:0]   - mantissa (8 bits, implied hidden bit)
//
// Multiplication algorithm:
//   sign = A_sign XOR B_sign
//   exp = A_exp + B_exp - bias
//   mant = (1.A_mant) × (1.B_mant) → normalize
//
// φ² + 1/φ² = 3 | TRINITY

`timescale 1ns / 1ps

module gf16_multiplier (
    // Clock and reset
    input wire        clk,
    input wire        rst,

    // Data input (AXI-Stream compatible handshake)
    input wire        in_valid,
    input wire [14:0] in_a,    // GF16 operand A
    input wire [14:0] in_b,    // GF16 operand B
    output wire        in_ready,

    // Data output
    output wire        out_valid,
    output wire [14:0] out_y,
    input wire        out_ready
);

    // ========================================================================
    // Stage 1: Decode A and B
    // ========================================================================

    // Decode A
    wire        a_sign;
    wire [5:0]  a_exp;
    wire [7:0]  a_mant;

    assign a_sign = in_a[14];
    assign a_exp  = in_a[13:8];
    assign a_mant = in_a[7:0];

    // Decode B
    wire        b_sign;
    wire [5:0]  b_exp;
    wire [7:0]  b_mant;

    assign b_sign = in_b[14];
    assign b_exp  = in_b[13:8];
    assign b_mant = in_b[7:0];

    // ========================================================================
    // Stage 2: Core Multiplication
    // ========================================================================

    // Sign: XOR
    wire        result_sign;
    assign result_sign = a_sign ^ b_sign;

    // Exponent: sum (bias will be subtracted later)
    wire [6:0]  exp_sum;  // 7 bits for carry
    assign exp_sum = {1'b0, a_exp} + {1'b0, b_exp};

    // Mantissa: (1.A_mant) × (1.B_mant) → 16-bit product
    // Use DSP48E1-friendly width (9 × 9 = 18 bits, we use lower 16)
    wire [8:0]  a_mant_ext = {1'b1, a_mant};  // 9 bits with hidden bit
    wire [8:0]  b_mant_ext = {1'b1, b_mant};
    wire [17:0] mant_product;                  // 18-bit product

    // This multiplication will map to DSP48E1
    assign mant_product = a_mant_ext * b_mant_ext;

    // ========================================================================
    // Stage 3: Normalize
    // ========================================================================

    // Check if product overflowed (bit 17 is set)
    wire        overflow = mant_product[17];

    // Normalize: shift if overflow
    wire [15:0] mant_normalized;
    wire [5:0]  exp_normalized;

    assign mant_normalized = overflow ? mant_product[17:2] : mant_product[16:1];
    assign exp_normalized  = exp_sum[6:1] + (overflow ? 6'd1 : 6'd0);

    // ========================================================================
    // Stage 4: Round and Pack
    // ========================================================================

    // Round to nearest even (simplified: truncate)
    // mant_normalized[15:8] is the 8-bit mantissa result
    wire [7:0] mant_final = mant_normalized[15:8];
    wire [5:0] exp_final  = exp_normalized;

    // Pack result: [14]=sign, [13:8]=exp, [7:0]=mant
    wire [14:0] result_packed;

    assign result_packed = {result_sign, exp_final, mant_final};

    // ========================================================================
    // Pipeline Registers
    // ========================================================================

    reg [14:0] stage1_reg_a, stage1_reg_b;
    reg [14:0] stage2_reg;
    reg [14:0] stage3_reg;
    reg        stage1_valid;
    reg        stage2_valid;
    reg        stage3_valid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            stage1_reg_a <= 15'b0;
            stage1_reg_b <= 15'b0;
            stage2_reg   <= 15'b0;
            stage3_reg   <= 15'b0;
            stage1_valid <= 1'b0;
            stage2_valid <= 1'b0;
            stage3_valid <= 1'b0;
        end else begin
            // Stage 1: Capture inputs
            stage1_reg_a <= in_a;
            stage1_reg_b <= in_b;
            stage1_valid <= in_valid;

            // Stage 2: Multiply
            if (stage1_valid) begin
                stage2_reg <= result_packed;
                stage2_valid <= 1'b1;
            end

            // Stage 3: Normalize
            if (stage2_valid) begin
                stage3_reg <= result_packed;
                stage3_valid <= 1'b1;
            end
        end
    end

    // ========================================================================
    // Output assignment
    // ========================================================================

    assign in_ready  = ~stage3_valid | out_ready;
    assign out_valid = stage3_valid;
    assign out_y     = stage3_reg;

endmodule
