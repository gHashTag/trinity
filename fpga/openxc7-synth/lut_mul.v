`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════════
// LUT Multiplier for TRINITY CORE V2
// ═══════════════════════════════════════════════════════════════════════════════
//
// 32-bit × 32-bit → 32-bit multiplier (lower word)
// - 3-cycle pipeline latency
// - Uses LUT-based multiplication (compatible with nextpnr-xilinx)
//
// ═══════════════════════════════════════════════════════════════════════════════

module lut_mul (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] result,
    output reg         valid_out
);

    // Pipeline registers
    reg [31:0] a_reg[0:2];
    reg [31:0] b_reg[0:2];
    reg [2:0] valid_reg;

    // LUT-based 32x32 multiplication
    wire [63:0] mult_result = a_reg[2] * b_reg[2];

    assign result = mult_result[31:0];

    // Pipeline stages
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
            // Stage 0: Capture inputs
            a_reg[0] <= a;
            b_reg[0] <= b;

            // Stage 1: First pipeline register
            a_reg[1] <= a_reg[0];
            b_reg[1] <= b_reg[0];

            // Stage 2: Second pipeline register (multiply happens here)
            a_reg[2] <= a_reg[1];
            b_reg[2] <= b_reg[1];

            // Valid signal pipeline
            valid_reg <= {valid_reg[1:0], valid_in};
            valid_out <= valid_reg[2];
        end
    end

endmodule
