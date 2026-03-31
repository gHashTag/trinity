// GF16 Multiplier Top — XC7A100T-FGG676 (QMTECH)
// BENCH-005: FPGA Synthesis — LUT/FF/DSP/Fmax measurement
//
// Target: QMTECH XC7A100T-FGG676
// Tool: Vivado (synth_design)
// Metric: LUT, FF, DSP, Fmax (MHz)
//
// Usage:
//   vivado -mode batch -source gf16_mul_synth.tcl

`default_nettype none

module gf16_mul_top (
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 16'h0000;
            b_reg <= 16'h0000;
        end else begin
            a_reg <= a;
            b_reg <= b;
        end
    end

    // ========================================================================
    // GF16 MULTIPLIER
    // ========================================================================
    // Decode GF16: [sign:1][exp:6][mant:9]
    wire sign_a = a_reg[15];
    wire sign_b = b_reg[15];
    wire [5:0] exp_a = a_reg[14:9];
    wire [5:0] exp_b = b_reg[14:9];
    wire [8:0] mant_a = {1'b1, a_reg[8:0]};  // Add implicit 1
    wire [8:0] mant_b = {1'b1, b_reg[8:0]};

    // Sign
    wire sign_result = sign_a ^ sign_b;

    // Multiply mantissas (18x18 → 32 bit, then truncate)
    wire [17:0] mul_mant_a = {9'b0, mant_a};
    wire [17:0] mul_mant_b = {9'b0, mant_b};
    wire [17:0] mul_product_raw = mul_mant_a * mul_mant_b;

    wire mul_overflow = mul_product_raw[17];
    wire [17:0] mul_product = mul_overflow ? {1'b0, mul_product_raw[17:1]} : mul_product_raw;
    wire [9:0] mul_mant = mul_product[9:0];

    // Add exponents (with bias adjustment)
    localparam GF16_EXP_BIAS = 31;
    wire [6:0] exp_sum = {1'b0, exp_a} + {1'b0, exp_b};
    wire [6:0] exp_mul_product = exp_sum - GF16_EXP_BIAS;
    wire [6:0] exp_mul_adj = mul_overflow ? (exp_mul_product + 7'd1) : exp_mul_product;

    // Normalize (leading zero count)
    wire [3:0] lz_count =
        (mul_mant[9]) ? 4'd0 :
        (mul_mant[8]) ? 4'd1 :
        (mul_mant[7]) ? 4'd2 :
        (mul_mant[6]) ? 4'd3 :
        (mul_mant[5]) ? 4'd4 :
        (mul_mant[4]) ? 4'd5 :
        (mul_mant[3]) ? 4'd6 :
        (mul_mant[2]) ? 4'd7 :
        (mul_mant[1]) ? 4'd8 :
        4'd9;

    wire [9:0] mant_normalized =
        (lz_count == 4'd0) ? mul_mant :
        (lz_count == 4'd1) ? {mul_mant[8:0], 1'b0} :
        (lz_count == 4'd2) ? {mul_mant[7:0], 2'b0} :
        (lz_count == 4'd3) ? {mul_mant[6:0], 3'b0} :
        (lz_count == 4'd4) ? {mul_mant[5:0], 4'b0} :
        (lz_count == 4'd5) ? {mul_mant[4:0], 5'b0} :
        (lz_count == 4'd6) ? {mul_mant[3:0], 6'b0} :
        (lz_count == 4'd7) ? {mul_mant[2:0], 7'b0} :
        (lz_count == 4'd8) ? {mul_mant[1:0], 8'b0} :
        10'h100;

    wire [5:0] exp_normalized = exp_mul_adj - lz_count;

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

    wire [15:0] mul_result = {sign_result, exp_result_clamped, mant_result};

    // ========================================================================
    // OUTPUT REGISTER (for fair Fmax measurement)
    // ========================================================================
    reg [15:0] result_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_reg <= 16'h0000;
        end else begin
            result_reg <= mul_result;
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
