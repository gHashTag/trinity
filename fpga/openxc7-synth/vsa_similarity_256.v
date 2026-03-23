//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// VSA Similarity Operation on FPGA - 256 dimensions
// Week 3: Dot product + normalization
//
// Balanced Ternary: {-1, 0, +1}
// Dot product: sum(a[i] * b[i]) for all i
// Similarity: dot / (norm(a) * norm(b)) = dot / sqrt(dot(a,a) * dot(b,b))
//
// This module returns raw dot product (-256 to +256)
// Full normalization requires floating point (host CPU or FPGA DSP)

module vsa_similarity_256 (
    input  wire clk,
    input  wire rst,
    input  wire valid_in,
    input  wire [511:0] a,      // 256 trits × 2 bits
    input  wire [511:0] b,      // 256 trits × 2 bits
    output reg  valid_out,
    output reg  signed [18:0] dot_product  // Range: -256 to +256 (use 9-bit signed)
);

    // Trit encoding: 2-bit signed ternary
    // 00 =  0
    // 01 = +1
    // 10 = -1

    // Trit product: a * b
    // -1 * -1 = +1 (1)
    // -1 *  0 =  0 (0)
    // -1 * +1 = -1 (-1)
    //  0 *  X =  0 (0)
    // +1 * +1 = +1 (1)

    // Generate 256 trit products
    wire signed [1:0] trit_product [255:0];

    genvar i;
    generate
        for (i = 0; i < 256; i = i + 1) begin : trit_mult
            wire [1:0] a_trit = a[2*i +: 2];
            wire [1:0] b_trit = b[2*i +: 2];

            // Trit multiplication (same as bind)
            // -1 * -1 = +1 (1)
            // -1 *  0 =  0 (0)
            // -1 * +1 = -1 (-1)
            //  0 *  X =  0 (0)
            // +1 * +1 = +1 (1)
            assign trit_product[i] =
                (a_trit == 2'b00 || b_trit == 2'b00) ? 2'd0 :
                (a_trit == b_trit) ? 2'd1 : 2'd11;  // 2'd11 = -1 in signed 2-bit
        end
    endgenerate

    // Accumulate products using a tree structure
    // Level 1: 256 adders → 128 values
    wire signed [3:0] level1 [127:0];
    generate
        for (i = 0; i < 128; i = i + 1) begin : tree_l1
            assign level1[i] = trit_product[2*i] + trit_product[2*i + 1];
        end
    endgenerate

    // Level 2: 128 adders → 64 values
    wire signed [4:0] level2 [63:0];
    generate
        for (i = 0; i < 64; i = i + 1) begin : tree_l2
            assign level2[i] = level1[2*i] + level1[2*i + 1];
        end
    endgenerate

    // Level 3: 64 adders → 32 values
    wire signed [5:0] level3 [31:0];
    generate
        for (i = 0; i < 32; i = i + 1) begin : tree_l3
            assign level3[i] = level2[2*i] + level2[2*i + 1];
        end
    endgenerate

    // Level 4: 32 adders → 16 values
    wire signed [6:0] level4 [15:0];
    generate
        for (i = 0; i < 16; i = i + 1) begin : tree_l4
            assign level4[i] = level3[2*i] + level3[2*i + 1];
        end
    endgenerate

    // Level 5: 16 adders → 8 values
    wire signed [7:0] level5 [7:0];
    generate
        for (i = 0; i < 8; i = i + 1) begin : tree_l5
            assign level5[i] = level4[2*i] + level4[2*i + 1];
        end
    endgenerate

    // Level 6: 8 adders → 4 values
    wire signed [8:0] level6 [3:0];
    generate
        for (i = 0; i < 4; i = i + 1) begin : tree_l6
            assign level6[i] = level5[2*i] + level5[2*i + 1];
        end
    endgenerate

    // Level 7: 4 adders → 2 values
    wire signed [9:0] level7 [1:0];
    generate
        for (i = 0; i < 2; i = i + 1) begin : tree_l7
            assign level7[i] = level6[2*i] + level6[2*i + 1];
        end
    endgenerate

    // Level 8: 2 adders → 1 value (final result)
    wire signed [10:0] raw_dot = level7[0] + level7[1];

    // Pipeline stage
    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 0;
            dot_product <= 0;
        end else begin
            valid_out <= valid_in;
            // Sign-extend to output register
            dot_product <= {{9{raw_dot[10]}}, raw_dot};  // Sign-extend 11-bit to 19-bit
        end
    end

endmodule

// φ² + 1/φ² = 3 = TRINITY
