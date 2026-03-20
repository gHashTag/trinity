`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════
// TF3-9 ADDER — Ternary Float 9 Addition
// ═════════════════════════════════════════════════════════════════════════
//
// TF3-9 format: 18-bit ternary float (9 trits total)
//   sign_trit:   2 bits   // {-1,0,+1} → (01, 00, 10)
//   exp_trits:    3 trits  // 6 bits
//   mant_trits:   5 trits  // 10 bits
//
// exp:mant (by trits) = 3:5 → ratio 0.6, φ-distance ≈ 0.018
//
// Trit encoding: 00 = -1, 01 = 0, 10 = +1, 11 = reserved
//
// Pipeline stages:
//   Stage 1: Decode trits to signed values
//   Stage 2: Align exponents, add mantissas
//   Stage 3: Normalize + encode back to trits
//
// Reference: src/hslm/intraparietal_sulcus.zig (tf3FromF32, tf3ToF32)
//
// φ² + 1/φ² = 3 | TRINITY

module tf3_add (
    input  wire clk,
    input  wire rst_n,

    // Handshake interface
    input  wire in_valid,
    output wire in_ready,
    input  wire [1:0] in_op,  // 00=ADD, 01=SUB (future), 10=DOT (future), 11=reserved

    // Operands (TF3-9 format: [sign_trit:2][exp_trits:6][mant_trits:10])
    input  wire [17:0] in_a,
    input  wire [17:0] in_b,

    // Output handshake
    output reg out_valid,
    input  wire out_ready,
    output reg [17:0] out_y
);

    // ====================================================================
    // TRIT DECODE FUNCTIONS
    // ====================================================================
    // Decode 2-bit trit to signed value: {-1, 0, +1}
    // Encoding: 00 = -1, 01 = 0, 10 = +1, 11 = 0 (reserved → 0)
    function [1:0] trit_to_signed;
        input [1:0] trit;
        begin
            case (trit)
                2'b00: trit_to_signed = -2'sd1;   // -1
                2'b01: trit_to_signed = 2'sd0;    // 0
                2'b10: trit_to_signed = 2'sd1;    // +1
                default: trit_to_signed = 2'sd0;     // Reserved → 0
            endcase
        end
    endfunction

    // Decode 3 trits (6 bits) to signed value
    // Balanced ternary: each trit is -1, 0, or +1
    function signed [3:0] trits3_to_signed;
        input [5:0] trits;
        reg [1:0] t0, t1, t2;
        begin
            t0 = trits[1:0];
            t1 = trits[3:2];
            t2 = trits[5:4];

            t0 = (t0 == 2'b11) ? 2'b01 : t0;
            t1 = (t1 == 2'b11) ? 2'b01 : t1;
            t2 = (t2 == 2'b11) ? 2'b01 : t2;

            trits3_to_signed = {trit_to_signed(t2), trit_to_signed(t1), trit_to_signed(t0)};
        end
    endfunction

    // Decode 5 trits (10 bits) to signed value
    function signed [4:0] trits5_to_signed;
        input [9:0] trits;
        reg [1:0] t [0:4];
        integer i;
        begin
            for (i = 0; i < 5; i = i + 1) begin
                t[i] = trits[i*2 +: 2];
                if (t[i] == 2'b11)
                    t[i] = 2'b01;  // Reserved → 0
            end
            trits5_to_signed = {
                trit_to_signed(t[4]),
                trit_to_signed(t[3]),
                trit_to_signed(t[2]),
                trit_to_signed(t[1]),
                trit_to_signed(t[0])
            };
        end
    endfunction

    // Encode signed value to 2-bit trit
    function [1:0] signed_to_trit;
        input signed [1:0] val;
        begin
            case (val)
                -2'sd1: signed_to_trit = 2'b00;  // -1
                2'sd0:  signed_to_trit = 2'b01;  // 0
                2'sd1:  signed_to_trit = 2'b10;  // +1
                default:  signed_to_trit = 2'b01;  // Default → 0
            endcase
        end
    endfunction

    // ====================================================================
    // DECODE STAGE (Stage 1)
    // ====================================================================
    wire [1:0] sign_trit_a = in_a[17:16];
    wire [1:0] sign_trit_b = in_b[17:16];
    wire [5:0] exp_trits_a = in_a[15:10];
    wire [5:0] exp_trits_b = in_b[15:10];
    wire [9:0] mant_trits_a = in_a[9:0];
    wire [9:0] mant_trits_b = in_b[9:0];

    // Decode to signed values
    wire signed [1:0] sign_a = trit_to_signed(sign_trit_a);
    wire signed [1:0] sign_b = trit_to_signed(sign_trit_b);
    wire signed [3:0] exp_a = trits3_to_signed(exp_trits_a);
    wire signed [3:0] exp_b = trits3_to_signed(exp_trits_b);
    wire signed [4:0] mant_a = trits5_to_signed(mant_trits_a);
    wire signed [4:0] mant_b = trits5_to_signed(mant_trits_b);

    // Zero detection
    wire is_zero_a = (sign_trit_a == 2'b01) & (exp_trits_a == 6'd0) & (mant_trits_a == 10'd0);
    wire is_zero_b = (sign_trit_b == 2'b01) & (exp_trits_b == 6'd0) & (mant_trits_b == 10'd0);
    wire is_result_zero = is_zero_a | is_zero_b;

    // Sign for addition (XOR)
    wire signed [1:0] sign_add = sign_a ^ sign_b;

    // ====================================================================
    // EXPONENT ALIGNMENT (Stage 1 cont.)
    // ====================================================================
    wire [4:0] exp_diff = exp_a - exp_b;  // signed difference
    wire [3:0] shift_a = 4'd0;  // if exp_a >= exp_b, don't shift A
    wire [3:0] shift_b = (exp_diff[4]) ? 4'd15 : exp_diff[3:0];  // Max shift = 15

    // Shift mantissa B right by exp difference (simple integer shift)
    wire signed [4:0] mant_b_shifted =
        (shift_b == 4'd0) ? mant_b :
        (shift_b == 4'd1) ? mant_b >> 4'sd1 :
        (shift_b == 4'd2) ? mant_b >> 4'sd2 :
        (shift_b == 4'd3) ? mant_b >> 4'sd3 :
        (shift_b == 4'd4) ? mant_b >> 4'sd4 :
        (shift_b == 4'd5) ? mant_b >> 4'sd5 :
        (shift_b == 4'd6) ? mant_b >> 4'sd6 :
        (shift_b == 4'd7) ? mant_b >> 4'sd7 :
        (shift_b == 4'd8) ? mant_b >> 4'sd8 :
        (shift_b == 4'd9) ? mant_b >> 4'sd9 :
        (shift_b == 4'd10) ? mant_b >> 4'sd10 :
        (shift_b == 4'd11) ? mant_b >> 4'sd11 :
        (shift_b == 4'd12) ? mant_b >> 4'sd12 :
        (shift_b == 4'd13) ? mant_b >> 4'sd13 :
        (shift_b == 4'd14) ? mant_b >> 4'sd14 :
        (shift_b == 4'd15) ? 5'sd0 :  // Shift to zero (underflow)
        5'sd0;  // Should not happen

    // ====================================================================
    // CORE ADDITION STAGE (Stage 2)
    // ====================================================================
    // Add mantissas (extend to 5 bits + carry)
    wire signed [5:0] mant_sum = mant_a + mant_b_shifted;

    // Carry out (bit 5)
    wire carry_out = mant_sum[5];

    // Result exponent (same as larger exponent)
    wire signed [3:0] exp_aligned = (exp_a >= exp_b) ? exp_a : exp_b;

    // Check if mantissa overflow
    wire mant_overflow = carry_out;

    // Normalized mantissa
    wire signed [4:0] mant_add_result = mant_overflow ? (mant_sum >> 5'sd1) : mant_sum[4:0];
    wire signed [3:0] exp_add_norm = mant_overflow ? (exp_aligned + 4'sd1) : exp_aligned;

    // ====================================================================
    // NORMALIZATION STAGE (Stage 3)
    // ====================================================================
    // Leading zero count
    wire [2:0] lz_count =
        (mant_add_result[4]) ? 3'd0 :
        (mant_add_result[3]) ? 3'd1 :
        (mant_add_result[2]) ? 3'd2 :
        (mant_add_result[1]) ? 3'd3 :
        (mant_add_result[0]) ? 3'd4 :
        3'd0;

    // Normalized mantissa (shift left by leading zeros)
    wire signed [4:0] mant_normalized =
        (lz_count == 3'd0) ? mant_add_result :
        (lz_count == 3'd1) ? {mant_add_result[3:0], 1'b0} :
        (lz_count == 3'd2) ? {mant_add_result[2:0], 2'b0} :
        (lz_count == 3'd3) ? {mant_add_result[1:0], 3'b0} :
        (lz_count == 3'd4) ? {mant_add_result[0], 4'b0} :
        5'sd0;

    // Adjusted exponent
    wire signed [3:0] exp_adjusted = exp_add_norm - lz_count;

    // ====================================================================
    // EXPONENT CLAMPING
    // ====================================================================
    // For TF3-9, exp range is -13 to +13 (in balanced ternary)
    wire exp_underflow = (exp_adjusted < -4'sd13);
    wire exp_overflow = (exp_adjusted > 4'sd13);

    wire signed [3:0] exp_final =
        exp_underflow ? -4'sd13 :
        exp_overflow ? 4'sd13 :
        exp_adjusted;

    // ====================================================================
    // ENCODING STAGE (Stage 3 cont.)
    // ====================================================================
    // Encode mantissa (4-bit signed) to 5 trits (10 bits)
    // Simple approach: take lower 5 bits as signed, encode each to trit
    wire [1:0] mant_t0 = signed_to_trit(mant_normalized[0]);
    wire [1:0] mant_t1 = signed_to_trit(mant_normalized[1]);
    wire [1:0] mant_t2 = signed_to_trit(mant_normalized[2]);
    wire [1:0] mant_t3 = signed_to_trit(mant_normalized[3]);
    wire [1:0] mant_t4 = signed_to_trit(mant_normalized[4]);

    wire [9:0] mant_trits_final = {
        mant_t4, mant_t3, mant_t2, mant_t1, mant_t0
    };

    // Encode exponent (3-bit signed) to 3 trits (6 bits)
    wire [1:0] exp_t0 = signed_to_trit(exp_final[0]);
    wire [1:0] exp_t1 = signed_to_trit(exp_final[1]);
    wire [1:0] exp_t2 = signed_to_trit(exp_final[2]);

    wire [5:0] exp_trits_final = {exp_t2, exp_t1, exp_t0};

    // Sign trit for addition
    wire [1:0] sign_trit_final = signed_to_trit(sign_add);

    // Zero detection
    wire is_final_zero = is_result_zero | (exp_final == 3'd0) & (mant_normalized == 5'sd0);

    // ====================================================================
    // PIPELINE REGISTERS
    // ====================================================================
    reg [1:0] sign_trit_r;
    reg [5:0] exp_trits_r;
    reg [9:0] mant_trits_r;
    reg final_zero_r;
    reg [1:0] valid_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sign_trit_r <= 2'b01;
            exp_trits_r <= 6'd0;
            mant_trits_r <= 10'd0;
            final_zero_r <= 1'b1;
            valid_pipe <= 2'd0;
            out_valid <= 1'b0;
            out_y <= 18'd0;
            in_ready <= 1'b1;
        end else begin
            valid_pipe <= {valid_pipe[0], in_valid};
            in_ready <= out_ready;

            sign_trit_r <= sign_trit_final;
            exp_trits_r <= exp_trits_final;
            mant_trits_r <= mant_trits_final;
            final_zero_r <= is_final_zero;

            out_valid <= valid_pipe[1];
            out_y <= final_zero_r ? 18'd0 : {sign_trit_r, exp_trits_r, mant_trits_r};
        end
    end

endmodule
