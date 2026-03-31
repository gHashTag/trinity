// Ternary Adder Top — Unit-level FPGA cost measurement (BENCH-005)
// Single ternary addition: a, b, c ∈ {-1, 0, +1} → result ∈ {-2, -1, 0, +1, +2}
// Target: Compare GF16 add (118 LUT) vs ternary add (expected ~5–15 LUT)

`default_nettype none

module ternary_add_top (
    input  wire clk,
    input  wire rst_n,
    input  wire [1:0] a,    // 2-bit signed: 00=-1, 01=0, 10=+1, 11=unused
    input  wire [1:0] b,    // 2-bit signed: 00=-1, 01=0, 10=+1, 11=unused
    output wire [2:0] result, // 3-bit signed: -2 to +2
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
    // TERNARY ADDER
    // ========================================================================
    // Decode 2-bit ternary: 00=-1, 01=0, 10=+1
    wire [1:0] a_val = a_reg == 2'b00 ? 2'b11 :   // -1 (signed 3-bit: 111)
                     a_reg == 2'b01 ? 2'b00 :   // 0
                                        2'b01;   // +1

    wire [1:0] b_val = b_reg == 2'b00 ? 2'b11 :   // -1
                     b_reg == 2'b01 ? 2'b00 :   // 0
                                        2'b01;   // +1

    // Sign-extend to 3 bits and add
    wire signed [2:0] a_signed = { {1{a_val[1]}}, a_val };  // sign-extend
    wire signed [2:0] b_signed = { {1{b_val[1]}}, b_val };  // sign-extend
    wire signed [2:0] sum = a_signed + b_signed;

    // ========================================================================
    // OUTPUT REGISTER (for fair Fmax measurement)
    // ========================================================================
    reg [2:0] result_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_reg <= 3'b000;
        end else begin
            result_reg <= sum;
        end
    end

    assign result = result_reg;

    // ========================================================================
    // STATUS LED — T23 (active-low, D6)
    // ========================================================================
    assign led = rst_n ? 1'b0 : 1'b1;  // ON when not reset

endmodule
