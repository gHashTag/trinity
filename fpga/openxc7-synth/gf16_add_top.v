// GF16 Adder Top — XC7A100T-FGG676 (QMTECH)
// BENCH-005: FPGA Synthesis — LUT/FF/Fmax measurement
//
// Target: QMTECH XC7A100T-FGG676
// Tool: Vivado (synth_design)
// Metric: LUT, FF, DSP, Fmax (MHz)
//
// Usage:
//   vivado -mode batch -source gf16_add_synth.tcl

`default_nettype none

module gf16_add_top (
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [15:0] result,
    output wire led           // Status LED (T23, active-low)
);

    // ========================================================================
    // INPUT REGISTERS (for fair Fmax measurement)
    // ========================================================================
    reg [15:0] a_reg;
    reg [15:0] b_reg;
    reg valid_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 16'h0000;
            b_reg <= 16'h0000;
            valid_reg <= 1'b0;
        end else begin
            a_reg <= a;
            b_reg <= b;
            valid_reg <= 1'b1;
        end
    end

    // ========================================================================
    // GF16 ADDER (from gf16_add.v)
    // ========================================================================
    wire [15:0] add_result;

    // Decode GF16: [sign:1][exp:6][mant:9]
    wire sign_a = a_reg[15];
    wire sign_b = b_reg[15];
    wire [5:0] exp_a = a_reg[14:9];
    wire [5:0] exp_b = b_reg[14:9];
    wire [8:0] mant_a = {1'b1, a_reg[8:0]};  // Add implicit 1
    wire [8:0] mant_b = {1'b1, b_reg[8:0]};

    // Exponent difference
    wire [5:0] exp_diff = exp_a - exp_b;
    wire [4:0] shift_b = exp_diff[5] ? 5'h1F : exp_diff[4:0];

    // Shift mantissa B right (barrel shifter)
    wire [8:0] mant_b_shifted;
    assign mant_b_shifted =
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

    // Add mantissas
    wire [9:0] mant_sum = mant_a + mant_b_shifted;
    wire carry_out = mant_sum[9];

    // Normalize
    wire mant_overflow = carry_out;
    wire [9:0] mant_add_result = mant_overflow ? {1'b0, mant_sum[9:1]} : mant_sum;
    wire [5:0] exp_add_norm = mant_overflow ? (exp_aligned + 6'd1) : exp_aligned;

    // Sign
    wire sign_result = sign_a ^ sign_b;

    // Leading zero count (for normalization)
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
        10'h100;

    wire [5:0] exp_normalized = exp_add_norm - lz_count;

    // Saturation (GF16: exp in [1, 62])
    localparam GF16_MAX_EXP = 6'd62;
    localparam GF16_MIN_EXP = 6'd1;

    wire exp_overflow = (exp_normalized >= GF16_MAX_EXP);
    wire exp_underflow = (exp_normalized < GF16_MIN_EXP);

    wire [5:0] exp_final =
        exp_overflow ? GF16_MAX_EXP :
        exp_underflow ? GF16_MIN_EXP :
        exp_normalized;

    // Rounding (round to nearest, tie to even)
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

    // Final saturation check
    wire final_overflow = (exp_result >= GF16_MAX_EXP);
    wire [5:0] exp_result_clamped =
        final_overflow ? GF16_MAX_EXP :
        exp_result;

    assign add_result = {sign_result, exp_result_clamped, mant_result};

    // ========================================================================
    // OUTPUT REGISTER (for fair Fmax measurement)
    // ========================================================================
    reg [15:0] result_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_reg <= 16'h0000;
        end else begin
            result_reg <= add_result;
        end
    end

    assign result = result_reg;

    // ========================================================================
    // STATUS LED — T23 (active-low, D6)
    // ========================================================================
    // LED behavior:
    // - ON (0) = computation in progress or valid result
    // - OFF (1) = reset state
    assign led = rst_n ? 1'b0 : 1'b1;  // ON when not in reset

endmodule
