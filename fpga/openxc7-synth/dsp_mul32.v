`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY DSP48E1 MULTIPLIER — Yosys DSP inference
// ═══════════════════════════════════════════════════════════════════════════════
//
// Uses DSP48E1 inference through standard multiplication operators
// Yosys synth_xilinx will map multipliers to DSP48E1 when appropriate
//
// Key: Use unsigned multipliers with proper bit widths for DSP inference
// DSP48E1: 25-bit × 18-bit → 48-bit product
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

module dsp_mul32 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] result,
    output reg         valid_out
);

    // ================================================================
    // 32x32 MULTIPLIER using DSP inference
    // ================================================================
    //
    // Strategy: Split into smaller multipliers that Yosys can map to DSP
    // Each DSP48E1: 25-bit × 18-bit multiplier
    //
    // For 32×32 → 32-bit (lower word), we use:
    //   result[15:0]  = (A[15:0] × B[15:0])[15:0]
    //   result[31:16] = ((A[15:0] × B[31:16]) + (A[31:16] × B[15:0]) + carry)[15:0]

    // Pipeline stage 1: Register inputs
    reg [31:0] a_reg;
    reg [31:0] b_reg;
    reg valid_s1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 32'd0;
            b_reg <= 32'd0;
            valid_s1 <= 1'b0;
        end else begin
            a_reg <= a;
            b_reg <= b;
            valid_s1 <= valid_in;
        end
    end

    // ================================================================
    // MULTIPLIERS (DSP inference)
    // ================================================================
    // Using 25x18 multipliers for optimal DSP usage

    // M0: Lower 18 bits of A × lower 18 bits of B
    wire [47:0] m0 = a_reg[17:0] * b_reg[17:0];

    // M1: Upper 14 bits of A × lower 18 bits of B
    wire [31:0] m1 = a_reg[31:18] * b_reg[17:0];

    // M2: Lower 18 bits of A × upper 14 bits of B
    wire [31:0] m2 = a_reg[17:0] * b_reg[31:18];

    // ================================================================
    // Pipeline stage 2: Combine results
    // ================================================================
    reg [31:0] result_reg;
    reg valid_s2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_reg <= 32'd0;
            valid_s2 <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            // Lower 32 bits calculation:
            // [15:0]  = m0[15:0]
            // [31:16] = m0[31:18] + m1[13:0] + m2[13:0] + carry
            result_reg <= m0[31:0] + {m1[13:0], 2'd0} + {m2[13:0], 2'd0};
            valid_s2 <= valid_s1;
            valid_out <= valid_s2;
        end
    end

    assign result = result_reg;

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// UNIVERSAL MULTIPLIER (LUT or DSP selectable)
// ═══════════════════════════════════════════════════════════════════════════════

module universal_mul #(
    parameter USE_DSP = 1  // 1 = use DSP48E1, 0 = use LUT
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] result,
    output wire        valid_out
);

    generate
        if (USE_DSP == 1) begin : gen_dsp
            // DSP implementation
            wire dsp_valid;
            dsp_mul32 dsp_inst (
                .clk(clk),
                .rst_n(rst_n),
                .valid_in(valid_in),
                .a(a),
                .b(b),
                .result(result),
                .valid_out(dsp_valid)
            );
            assign valid_out = dsp_valid;

        end else begin : gen_lut
            // LUT implementation (original lut_mul)
            lut_mul lut_inst (
                .clk(clk),
                .rst_n(rst_n),
                .valid_in(valid_in),
                .a(a),
                .b(b),
                .result(result),
                .valid_out(valid_out)
            );
        end
    endgenerate

endmodule
