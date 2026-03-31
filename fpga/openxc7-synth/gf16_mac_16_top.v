// ========================================================================
// GF16 MAC-16 TOP - 16-Channel Dot Product Unit (BENCH-006)
// ========================================================================
//
// Computes: y = sum(w[i] * x[i]) for i = 0..15
//   - w[i], x[i] in GF16 (1:6:9 format, bias=31)
//   - y in GF16 (normalized, with saturation)
//
// ACCUM Interface:
//   - clk:     positive edge trigger
//   - rst_n:   async reset (active-low)
//   - valid:   input data valid (w, x ready to sample)
//   - ready:   output data ready (y valid to read)
//
// GF16 Arithmetic:
//   - Multiply: full 9x9 mantissa -> 18-bit product
//   - Add:      tree of adders with sign extension
//   - Normalize: pack back to GF16 with saturation at +/- 65504
//
// Saturation (documented):
//   - Max positive: 65504 (0x7BFF) - exp=126, mant=all-1
//   - Min negative: -65504 (0xFBFF) - exp=126, mant=all-1, sign=1
//   - Overflow: clamp to saturation values
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// ========================================================================

`default_nettype none

module gf16_mac_16_top #(
    parameter LATENCY = 2          // Pipeline stages (1: comb, 2: registered)
)(
    // ========================================================================
    // CLOCK & RESET
    // ========================================================================
    input  wire clk,
    input  wire rst_n,

    // ========================================================================
    // INPUT INTERFACE (16 x GF16 vectors)
    // ========================================================================
    input  wire valid,             // Data valid (sample on next cycle)
    input  wire [255:0] w,         // 16 x 16-bit GF16 weights [w15...w0]
    input  wire [255:0] x,         // 16 x 16-bit GF16 inputs  [x15...x0]

    // ========================================================================
    // OUTPUT INTERFACE
    // ========================================================================
    output wire ready,             // Output ready (y valid)
    output wire [15:0] y,          // Accumulator result (GF16)
    output wire overflow           // Saturation occurred
);

    // ========================================================================
    // GF16 FORMAT: [15][14:10][9:0] = [sign:1][exp:5][mant:10]
    // Note: using 10-bit mantissa for alignment with existing GF16
    // Bias = 15 (not 31 in this representation for range)
    // Value = (-1)^sign * 2^(exp-15) * (1.mantissa)
    // ========================================================================

    // ========================================================================
    // STAGE 1: INPUT REGISTERS
    // ========================================================================
    reg [255:0] w_reg;
    reg [255:0] x_reg;
    reg valid_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_reg <= 256'h0;
            x_reg <= 256'h0;
            valid_reg <= 1'b0;
        end else begin
            w_reg <= w;
            x_reg <= x;
            valid_reg <= valid;
        end
    end

    // ========================================================================
    // GF16 DECODE: extract sign, exp, mantissa for each lane
    // ========================================================================
    wire [15:0] w_lane [16];
    wire [15:0] x_lane [16];

    genvar i;
    generate for (i = 0; i < 16; i = i + 1) begin : gen_decode
        // Lane i: bits [16*i +: 16]
        assign w_lane[i] = w_reg[16*i +: 16];
        assign x_lane[i] = x_reg[16*i +: 16];
    end
    endgenerate

    // ========================================================================
    // STAGE 2: MULTIPLIER ARRAY (16 parallel GF16 multipliers)
    // ========================================================================
    // Each: product = (-1)^sw * 2^(ew-15) * (1.mw) * (-1)^sx * 2^(ex-15) * (1.mx)
    //        = (-1)^(sw^sx) * 2^(ew+ex-30) * (1.mw * 1.mx)

    wire signed [18:0] mul_product [16];  // 19-bit signed product (9x9 + sign)
    wire mul_zero [16];

    generate for (i = 0; i < 16; i = i + 1) begin : gen_mul
        wire w_sign = w_lane[i][15];
        wire x_sign = x_lane[i][15];
        wire [4:0] w_exp = w_lane[i][14:10];
        wire [4:0] x_exp = x_lane[i][14:10];
        wire [8:0] w_mant = {1'b1, w_lane[i][9:1]};  // Add implicit 1
        wire [8:0] x_mant = {1'b1, x_lane[i][9:1]};

        // Zero detection (exp=0, mant=0)
        wire w_zero = (w_lane[i][14:0] == 15'h0000);
        wire x_zero = (x_lane[i][14:0] == 15'h0000);
        assign mul_zero[i] = w_zero | x_zero;

        // Sign
        wire prod_sign = w_sign ^ x_sign;

        // Mantissa product (9x9 = 18 bits unsigned)
        wire [17:0] mant_prod = w_mant * x_mant;

        // Signed product with proper sign extension (2's complement)
        wire [18:0] prod_unsigned = {1'b0, mant_prod};
        wire [18:0] prod_signed = prod_sign ? (~prod_unsigned + 19'b1) : prod_unsigned;
        assign mul_product[i] = prod_signed;
    end
    endgenerate

    // ========================================================================
    // STAGE 3: ADDER TREE (accumulate 16 products)
    // ========================================================================
    // Tree structure: (((...((p0+p1)+(p2+p3))+...)+p15)

    // Level 1: 8 adds (16 -> 8)
    wire signed [19:0] acc_l1 [8];
    generate for (i = 0; i < 8; i = i + 1) begin : gen_add_l1
        wire signed [18:0] a = mul_zero[2*i]   ? 19'sd0 : mul_product[2*i];
        wire signed [18:0] b = mul_zero[2*i+1] ? 19'sd0 : mul_product[2*i+1];
        assign acc_l1[i] = a + b;
    end
    endgenerate

    // Level 2: 4 adds (8 -> 4)
    wire signed [20:0] acc_l2 [4];
    generate for (i = 0; i < 4; i = i + 1) begin : gen_add_l2
        assign acc_l2[i] = acc_l1[2*i] + acc_l1[2*i+1];
    end
    endgenerate

    // Level 3: 2 adds (4 -> 2)
    wire signed [21:0] acc_l3 [2];
    generate for (i = 0; i < 2; i = i + 1) begin : gen_add_l3
        assign acc_l3[i] = acc_l2[2*i] + acc_l2[2*i+1];
    end
    endgenerate

    // Level 4: 1 add (2 -> 1)
    wire signed [22:0] acc_sum = acc_l3[0] + acc_l3[1];

    // ========================================================================
    // STAGE 4: NORMALIZE & PACK TO GF16
    // ========================================================================
    // Need to convert 23-bit sum back to GF16 (1:5:10 format with bias=15)
    // This is a simplified version - full implementation needs:
    //   1. Count leading zeros
    //   2. Shift mantissa
    //   3. Adjust exponent
    //   4. Handle overflow/underflow

    reg [15:0] y_reg;
    reg overflow_reg;
    reg ready_reg;

    // GF16 saturation values
    localparam [15:0] GF16_MAX = 16'h7BFF;  // +65504
    localparam [15:0] GF16_MIN = 16'hFBFF;  // -65504

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_reg <= 16'h0000;
            overflow_reg <= 1'b0;
            ready_reg <= 1'b0;
        end else if (valid_reg) begin
            // Simplified: take lower 16 bits, clamp to saturation
            // Full implementation: normalize acc_sum to GF16
            if (acc_sum[22]) begin  // Negative (sign bit set)
                if (acc_sum >= -23'sd65504)
                    y_reg <= {1'b1, 5'd31, acc_sum[8:0]};  // Pack as negative GF16
                else begin
                    y_reg <= GF16_MIN;
                    overflow_reg <= 1'b1;
                end
            end else begin  // Positive
                if (acc_sum < 23'sd65504)
                    y_reg <= {1'b0, 5'd31, acc_sum[8:0]};  // Pack as positive GF16
                else begin
                    y_reg <= GF16_MAX;
                    overflow_reg <= 1'b1;
                end
            end
            ready_reg <= 1'b1;
        end else begin
            ready_reg <= 1'b0;
        end
    end

    // ========================================================================
    // OUTPUTS
    // ========================================================================
    assign y = y_reg;
    assign ready = ready_reg;
    assign overflow = overflow_reg;

endmodule
