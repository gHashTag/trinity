// Ternary Multiplier Top — Unit-level FPGA cost measurement (BENCH-005)
// Single ternary multiplication: a, b ∈ {-1, 0, +1} → result ∈ {-1, 0, +1}
// Target: Compare GF16 mul (94 LUT + 1 DSP) vs ternary mul (expected ~10–30 LUT, 0 DSP)

`default_nettype none

module ternary_mul_top (
    input  wire clk,
    input  wire rst_n,
    input  wire [1:0] a,    // 2-bit signed: 00=-1, 01=0, 10=+1, 11=unused
    input  wire [1:0] b,    // 2-bit signed: 00=-1, 01=0, 10=+1, 11=unused
    output wire [1:0] result, // 2-bit signed: -1, 0, +1
    output wire led           // Status LED (T23, active-low)
);

    // ========================================================================
    // INPUT REGISTERS (for fair Fmax measurement)
    // ========================================================================
    reg [1:0] a_reg;
    reg [1:0] b_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 2'b01;  // 0
            b_reg <= 2'b01;  // 0
        end else begin
            a_reg <= a;
            b_reg <= b;
        end
    end

    // ========================================================================
    // TERNARY MULTIPLIER
    // ========================================================================
    // Ternary multiply truth table:
    //     -1  0  +1
    // -1 +1  0  -1
    //  0  0  0   0
    // +1 -1  0  +1

    // Check for zero (either input is 0 → result is 0)
    wire a_is_zero = (a_reg == 2'b01);
    wire b_is_zero = (b_reg == 2'b10);
    wire mul_is_zero = a_is_zero | b_is_zero;

    // Check signs: 00=-1 (negative), 10=+1 (positive)
    wire a_is_neg = (a_reg == 2'b00);
    wire b_is_neg = (b_reg == 2'b00);
    wire result_is_neg = a_is_neg ^ b_is_neg;  // XOR for sign

    // Result: 01=-1, 10=0, 11=+1 (using 2 bits)
    wire [1:0] mul_result = mul_is_zero ? 2'b10 :              // 0
                                 result_is_neg ? 2'b01 :      // -1
                                                  2'b11;     // +1

    // ========================================================================
    // OUTPUT REGISTER (for fair Fmax measurement)
    // ========================================================================
    reg [1:0] result_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_reg <= 2'b10;  // 0
        end else begin
            result_reg <= mul_result;
        end
    end

    assign result = result_reg;

    // ========================================================================
    // STATUS LED — T23 (active-low, D6)
    // ========================================================================
    assign led = rst_n ? 1'b0 : 1'b1;  // ON when not reset

endmodule
