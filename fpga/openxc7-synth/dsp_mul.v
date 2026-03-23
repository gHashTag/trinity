//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════════
// DSP48E1 Wrapper for TRINITY CORE V2
// ═══════════════════════════════════════════════════════════════════════════════
//
// Wrapper for Xilinx DSP48E1 primitive to implement 32-bit multiplication
// - 32-bit × 32-bit → 32-bit result (lower word)
// - 3-cycle pipeline latency
// - Uses dedicated DSP slices (240 available on XC7A100T)
//
// ═══════════════════════════════════════════════════════════════════════════════

module dsp_mul (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,    // Input data valid
    input  wire [31:0] a,           // Multiplicand
    input  wire [31:0] b,           // Multiplier
    output wire [31:0] result,      // Product (lower 32 bits)
    output reg         valid_out    // Output data valid
);

    //==========================================================================
    // DSP48E1 Instance
    //==========================================================================
    // DSP48E1: 25-bit × 18-bit multiplier with 48-bit accumulator
    // For 32×32 multiply, we use cascading or split the operation
    //
    // Simplified approach: Use 25×18 multiplication for lower bits
    // Full 32×32 would require multiple DSPs or iterative approach

    // Pipeline registers
    reg [31:0] a_reg[0:2];
    reg [31:0] b_reg[0:2];
    reg [2:0] valid_reg;

    // For simplicity, using LUT-based multiply for full 32-bit
    // In production, would cascade multiple DSP48E1 for full precision
    wire [63:0] mult_result;

    // Using built-in multiplication operator
    // Yosys will infer DSP48E1 when possible
    assign mult_result = a_reg[2] * b_reg[2];

    assign result = mult_result[31:0];

    //==========================================================================
    // Pipeline
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg[0] <= 32'd0;
            a_reg[1] <= 32'd0;
            a_reg[2] <= 32'd0;
            b_reg[0] <= 32'd0;
            b_reg[1] <= 32'd0;
            b_reg[2] <= 32'd0;
            valid_reg <= 3'd0;
            valid_out <= 1'b0;
        end else begin
            // Shift pipeline
            a_reg[0] <= a;
            a_reg[1] <= a_reg[0];
            a_reg[2] <= a_reg[1];

            b_reg[0] <= b;
            b_reg[1] <= b_reg[0];
            b_reg[2] <= b_reg[1];

            valid_reg <= {valid_reg[1:0], valid_in};
            valid_out <= valid_reg[2];
        end
    end

endmodule
