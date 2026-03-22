// @origin(spec:gf16_adder.tri) @regen(manual-impl)
// GF16 Adder — Golden Float 16 Addition Unit
//
// GF16 format (15 bits + sign):
//   [14]    - sign bit (1 = negative)
//   [13:8]  - exponent (6 bits, bias TBD)
//   [7:0]   - mantissa (8 bits, implied hidden bit)
//
// φ² + 1/φ² = 3 | TRINITY

`timescale 1ns / 1ps

module gf16_adder (
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
    // Stage 1: Decode and Align Exponents
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

    // Calculate exponent difference
    wire [5:0]  exp_diff;
    wire        a_larger;  // 1 if |A| >= |B|

    assign exp_diff = a_exp - b_exp;
    assign a_larger = (a_exp >= b_exp);

    // Align mantissas (shift smaller mantissa right)
    wire [7:0]  a_mant_aligned;
    wire [7:0]  b_mant_aligned;
    wire [8:0]  a_mant_ext;  // 9-bit with hidden bit
    wire [8:0]  b_mant_ext;

    // Extend with hidden bit (assumed 1 for normalized numbers)
    assign a_mant_ext = {1'b1, a_mant};
    assign b_mant_ext = {1'b1, b_mant};

    // Shift aligner (barrel shifter for 0-63 shift)
    // Simple implementation: multiplexer based shift
    wire [8:0] a_shifted = a_larger ? a_mant_ext :
                                   (b_mant_ext >> exp_diff);
    wire [8:0] b_shifted = a_larger ? (b_mant_ext >> exp_diff) :
                                   b_mant_ext;

    assign a_mant_aligned = a_shifted[8:1];  // Drop overflow bit
    assign b_mant_aligned = b_shifted[8:1];

    // ========================================================================
    // Stage 2: Core Addition
    // ========================================================================

    // Determine result sign (XOR for same-sign, keep larger for diff-sign)
    wire        result_sign;
    wire [8:0]  mant_sum_raw;

    assign result_sign = (a_sign == b_sign) ? a_sign :
                       (a_larger) ? a_sign : b_sign;

    // Two's complement addition if signs differ
    wire [8:0]  a_mant_signed = a_sign ? ~a_mant_aligned + 1'b1 : a_mant_aligned;
    wire [8:0]  b_mant_signed = b_sign ? ~b_mant_aligned + 1'b1 : b_mant_aligned;

    // Add mantissas
    assign mant_sum_raw = a_mant_signed + b_mant_signed;

    // ========================================================================
    // Stage 3: Normalize
    // ========================================================================

    // Count leading zeros in mantissa (to normalize)
    // Simplified: check top bits
    wire [2:0] shift_amount;

    assign shift_amount = mant_sum_raw[8] ? 3'd0 :
                        mant_sum_raw[7] ? 3'd1 :
                        mant_sum_raw[6] ? 3'd2 :
                        3'd3;

    // Normalize: shift left by shift_amount
    wire [8:0] mant_normalized;
    wire [5:0] exp_normalized;

    assign mant_normalized = mant_sum_raw << shift_amount;
    assign exp_normalized = (a_larger ? a_exp : b_exp) - shift_amount + 6'd1;

    // ========================================================================
    // Stage 4: Round and Pack
    // ========================================================================

    // Round to nearest even (guard, round, sticky bits)
    // For simplicity: truncate (can be enhanced later)
    wire [7:0] mant_final = mant_normalized[8:1];  // Drop hidden bit
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

            // Stage 2: Align and add
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
