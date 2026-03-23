//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// TERNARY MATRIX-VECTOR MULTIPLY — FPGA Accelerator Core (v2: Sequential)
// =============================================================================
// Computes y[j] = sum_i W[i][j] * x[i]  where W[i][j] in {-1, 0, +1}
//
// Architecture: Fully sequential — one accumulation per clock
//   - Single accumulator processes one (i,j) pair per clock
//   - Outer loop: j = 0..63 (output index)
//   - Inner loop: i = 0..63 (input index)
//   - Total latency: 64 * 64 + overhead = ~4100 clocks = ~82 us @ 50 MHz
//   - Minimal LUT usage — synthesizes in seconds
//   - No DSP48 blocks — pure add/sub
//
// Self-test weights: W[i][j] = +1 if (i+j)%3==0, -1 if (i+j)%3==1, 0 else
// Self-test input:   x[i] = i + 1
// Expected output:   {43, -22, -21} repeating
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module ternary_matvec (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    output reg  [15:0] result_data,    // Current result word
    output reg  [5:0]  result_addr,    // Address of current result (0..63)
    output reg         result_valid,   // Pulse when result_data/addr valid
    output reg         done,           // All 64 outputs computed
    output reg         busy
);

    // =========================================================================
    // WEIGHT + INPUT LOOKUP (combinational, no ROM storage needed)
    // =========================================================================
    // Weight: W[i][j] = +1 if (i+j)%3==0, -1 if (i+j)%3==1, 0 if (i+j)%3==2
    // Encoding: 2'b01=+1, 2'b10=-1, 2'b00=0

    reg [5:0] i_idx;  // input index 0..63
    reg [5:0] j_idx;  // output index 0..63

    // Weight lookup — purely combinational from i+j
    wire [6:0] ij_sum;
    assign ij_sum = {1'b0, i_idx} + {1'b0, j_idx};

    // Mod 3 of ij_sum (7-bit value, max 126)
    // Use subtraction: mod3 = ij_sum - 3*(ij_sum/3)
    // For synthesis, Yosys handles % operator on small values
    wire [1:0] weight_code;
    assign weight_code = (ij_sum % 3 == 0) ? 2'b01 :  // +1
                         (ij_sum % 3 == 1) ? 2'b10 :  // -1
                                             2'b00 ;   //  0

    // Input lookup — x[i] = i + 1 (signed 8-bit, sign-extended to 16)
    wire signed [15:0] x_val;
    assign x_val = {10'd0, i_idx} + 16'sd1;  // i+1, always positive, fits in 16-bit

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    localparam S_IDLE    = 2'd0;
    localparam S_COMPUTE = 2'd1;
    localparam S_OUTPUT  = 2'd2;
    localparam S_DONE    = 2'd3;

    reg [1:0] state;
    reg signed [15:0] acc;

    always @(posedge clk) begin
        if (rst) begin
            state        <= S_IDLE;
            i_idx        <= 6'd0;
            j_idx        <= 6'd0;
            acc          <= 16'sd0;
            done         <= 1'b0;
            busy         <= 1'b0;
            result_valid <= 1'b0;
            result_data  <= 16'd0;
            result_addr  <= 6'd0;
        end else begin
            done         <= 1'b0;
            result_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        i_idx <= 6'd0;
                        j_idx <= 6'd0;
                        acc   <= 16'sd0;
                        busy  <= 1'b1;
                        state <= S_COMPUTE;
                    end
                end

                S_COMPUTE: begin
                    // Accumulate based on weight
                    case (weight_code)
                        2'b01: acc <= acc + x_val;  // +1
                        2'b10: acc <= acc - x_val;  // -1
                        default: ;                  //  0: skip
                    endcase

                    if (i_idx == 6'd63) begin
                        // Done with inner loop — output result for column j
                        state <= S_OUTPUT;
                    end else begin
                        i_idx <= i_idx + 1;
                    end
                end

                S_OUTPUT: begin
                    // Write result for column j
                    result_data  <= acc;
                    result_addr  <= j_idx;
                    result_valid <= 1'b1;

                    if (j_idx == 6'd63) begin
                        state <= S_DONE;
                    end else begin
                        // Next column
                        j_idx <= j_idx + 1;
                        i_idx <= 6'd0;
                        acc   <= 16'sd0;
                        state <= S_COMPUTE;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
