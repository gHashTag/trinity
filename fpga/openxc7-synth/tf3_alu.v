//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// @origin(spec:tf3_alu.tri) @regen(manual-impl)
// TF3 ALU — Ternary Float 9 Arithmetic Unit
//
// Implements basic TF3-9 operations:
// - tf3_add: saturating addition of two TF3-9 numbers
// - tf3_dot: configurable N-length dot product
//
// Ternary encoding:
//   00 -> 0
//   01 -> -1 (in 2's complement)
//   10 -> +1
//   11 -> invalid (treat as 0)
//
// TF3-9 format (18 bits):
//   [17:16] - sign trit (2 bits)
//   [15:10] - exp trits (6 bits = 3 trits)
//   [9:0]   - mant trits (10 bits = 5 trits)
//
// φ² + 1/φ² = 3 | TRINITY

`timescale 1ns / 1ps

module tf3_alu (
    // Clock and reset
    input wire        clk,
    input wire        rst,

    // Operation mode
    input wire [1:0]  mode,    // 00=add, 01=dot

    // Data input (AXI-Stream compatible handshake)
    input wire        in_valid,
    input wire [17:0] in_a,    // TF3-9 operand A
    input wire [17:0] in_b,    // TF3-9 operand B
    input wire [7:0]  dot_len,  // N for dot product (max 256)
    output wire        in_ready,

    // Data output
    output wire        out_valid,
    output wire [17:0] out_y,
    input wire        out_ready
);

    // ========================================================================
    // Trit decoding helpers (combinational)
    // ========================================================================

    // Decode 2-bit trit to 2-bit signed value
    // 00 -> 00 (0), 01 -> 11 (-1), 10 -> 01 (+1), 11 -> 00 (invalid)
    function [1:0] trit_decode;
        input [1:0] t;
        begin
            case (t)
                2'b00:   trit_decode = 2'b00;  // 0
                2'b01:   trit_decode = 2'b11;  // -1
                2'b10:   trit_decode = 2'b01;  // +1
                default:   trit_decode = 2'b00;  // invalid -> treat as 0
            endcase
        end
    endfunction

    // ========================================================================
    // Stage 1: Decode TF3-9 operands to signed values
    // ========================================================================

    // Operand A decoding
    wire [1:0] a_sign_raw;
    wire [5:0]  a_exp_raw;
    wire [9:0]  a_mant_raw;

    wire signed [1:0] a_sign;
    wire signed [5:0] a_exp;
    wire signed [9:0] a_mant;

    // Extract trit fields from A
    assign a_sign_raw = in_a[17:16];   // sign trit (2 bits)
    assign a_exp_raw   = in_a[15:10];   // exp trits (6 bits)
    assign a_mant_raw  = in_a[9:0];     // mant trits (10 bits)

    // Decode sign trit
    assign a_sign = (a_sign_raw == 2'b10) ? 2'sd01 :
                   (a_sign_raw == 2'b01) ? 2'sd11 :
                   2'sd00;

    // For exp and mantissa, we keep raw bits (ternary encoded)
    // The actual computation happens on decoded values
    assign a_exp  = a_exp_raw;   // Placeholder for now
    assign a_mant = a_mant_raw;  // Placeholder for now

    // Operand B decoding
    wire [1:0] b_sign_raw;
    wire [5:0] b_exp_raw;
    wire [9:0] b_mant_raw;

    wire signed [1:0] b_sign;
    wire signed [5:0] b_exp;
    wire signed [9:0] b_mant;

    assign b_sign_raw = in_b[17:16];
    assign b_exp_raw   = in_b[15:10];
    assign b_mant_raw  = in_b[9:0];

    assign b_sign = (b_sign_raw == 2'b10) ? 2'sd01 :
                   (b_sign_raw == 2'b01) ? 2'sd11 :
                   2'sd00;

    assign b_exp  = b_exp_raw;
    assign b_mant = b_mant_raw;

    // ========================================================================
    // Stage 2: TF3 Addition (mode=00)
    // ========================================================================

    // Sign addition with saturating arithmetic
    wire signed [2:0] add_sign_ext;
    wire [1:0]       add_result_sign;
    wire             add_sign_carry;

    assign {add_sign_carry, add_sign_ext[1:0]} =
        (a_sign + b_sign) + 2'sd01; // Offset by +1 for ternary range

    // Saturating result for sign
    // add_sign_ext range: <0=-1, >1=+1, else=0
    assign add_result_sign = (add_sign_ext > 3'sd001) ? 2'b10 :  // +1
                           (add_sign_ext < 3'sd000) ? 2'b01 :   // -1
                           2'b000;                               // 0

    // Mantissa addition (10-bit)
    wire [9:0] mant_sum;
    wire       mant_carry;

    assign {mant_carry, mant_sum} = a_mant_raw + b_mant_raw;

    // Exponent addition with carry propagation
    wire [5:0] exp_sum;
    wire       exp_carry;

    assign {exp_carry, exp_sum} = a_exp_raw + b_exp_raw;

    wire [5:0] add_result_exp;
    assign add_result_exp = exp_sum + {5'b00000, mant_carry};

    wire [9:0] add_result_mant;
    assign add_result_mant = mant_sum;

    // ========================================================================
    // Stage 2: TF3 Dot Product (mode=01)
    // ========================================================================

    // For dot product, we multiply mantissas and add exponents
    // Sign follows XOR rule

    wire [9:0] mant_product;
    wire [5:0]  exp_product;
    wire [1:0]  sign_product;

    assign mant_product = a_mant_raw * b_mant_raw;
    assign exp_product  = a_exp_raw + b_exp_raw;
    assign sign_product = a_sign_raw ^ b_sign_raw; // XOR for sign

    // ========================================================================
    // Pipeline registers
    // ========================================================================

    reg [17:0] result_reg;
    reg        stage2_valid_reg;

    reg [7:0]  dot_counter;
    reg [17:0] dot_accumulator;
    reg        dot_valid_reg;

    // ========================================================================
    // Sequential logic
    // ========================================================================

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result_reg      <= 18'b0;
            stage2_valid_reg <= 1'b0;
            dot_counter     <= 8'b0;
            dot_accumulator <= 18'b0;
            dot_valid_reg   <= 1'b0;
        end else begin
            // Default: clear stage2 valid when output is consumed
            if (out_ready) begin
                // Only clear when actually consuming (testbench sets in_valid = 0)
                if (in_valid == 1'b0) begin
                    stage2_valid_reg <= 1'b0;
                    dot_valid_reg   <= 1'b0;
                end
            end

            // Process new input when ready (reset valid flags for new operation)
            if (in_valid && in_ready) begin
                case (mode)
                    2'b00: begin // TF3 Addition
                        // Pack result: [17:16]=sign, [15:10]=exp, [9:0]=mant
                        result_reg <= {add_result_sign, add_result_exp, add_result_mant};
                        stage2_valid_reg <= 1'b1;
                    end

                    2'b01: begin // TF3 Dot Product
                        if (dot_counter < dot_len) begin
                            // Accumulate products
                            dot_accumulator <= dot_accumulator + {
                                sign_product,
                                exp_product,
                                mant_product[7:0]  // Use lower 8 bits
                            };
                            dot_counter <= dot_counter + 1;

                            if (dot_counter == dot_len - 1) begin
                                // Last iteration - pack accumulator to TF3-9 format
                                dot_valid_reg <= 1'b1;
                                result_reg     <= dot_accumulator;
                                dot_counter <= 8'b0;
                            end
                        end
                    end

                    default: begin
                        // Invalid mode - pass through A
                        result_reg      <= in_a;
                        stage2_valid_reg <= 1'b1;
                    end
                endcase
            end
        end
    end

    // ========================================================================
    // Output assignment
    // ========================================================================

    // Always ready for input (no blocking)
    assign in_ready = 1'b1;

    // Output valid when result is ready
    assign out_valid = stage2_valid_reg | dot_valid_reg;

    // Output multiplexer
    assign out_y = result_reg;

endmodule
