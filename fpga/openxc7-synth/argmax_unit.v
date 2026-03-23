//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// ARGMAX UNIT — Streaming Argmax over Vocabulary Logits
// =============================================================================
// Accepts streaming logits from lm_head_matvec and tracks the maximum value.
// When done_in fires, outputs the index of the maximum logit.
//
// Architecture:
//   - Single comparator, updated every valid input
//   - Stores current max_val and max_idx
//   - Zero BRAM, ~100 LUT
//   - Latency: 1 clock after done_in
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module argmax_unit #(
    parameter ACC_WIDTH = 32,
    parameter IDX_WIDTH = 8    // ceil(log2(VOCAB))
)(
    input  wire                        clk,
    input  wire                        rst,

    // Streaming input from lm_head_matvec
    input  wire                        in_valid,
    input  wire signed [ACC_WIDTH-1:0] in_data,
    input  wire [IDX_WIDTH-1:0]        in_addr,
    input  wire                        in_done,

    // Result
    output reg [IDX_WIDTH-1:0]         argmax_idx,
    output reg signed [ACC_WIDTH-1:0]  argmax_val,
    output reg                         argmax_valid,  // pulses when result ready
    output reg                         busy
);

    reg signed [ACC_WIDTH-1:0] max_val;
    reg [IDX_WIDTH-1:0]        max_idx;
    reg                        first_val;  // track if we've seen any value

    always @(posedge clk) begin
        if (rst) begin
            max_val      <= {1'b1, {(ACC_WIDTH-1){1'b0}}};  // most negative
            max_idx      <= {IDX_WIDTH{1'b0}};
            first_val    <= 1'b1;
            argmax_idx   <= {IDX_WIDTH{1'b0}};
            argmax_val   <= {ACC_WIDTH{1'b0}};
            argmax_valid <= 1'b0;
            busy         <= 1'b0;
        end else begin
            argmax_valid <= 1'b0;

            if (in_valid) begin
                busy <= 1'b1;
                if (first_val || (in_data > max_val)) begin
                    max_val   <= in_data;
                    max_idx   <= in_addr;
                    first_val <= 1'b0;
                end
            end

            if (in_done) begin
                argmax_idx   <= max_idx;
                argmax_val   <= max_val;
                argmax_valid <= 1'b1;
                busy         <= 1'b0;
                // Reset for next token
                max_val   <= {1'b1, {(ACC_WIDTH-1){1'b0}}};
                max_idx   <= {IDX_WIDTH{1'b0}};
                first_val <= 1'b1;
            end
        end
    end

endmodule
