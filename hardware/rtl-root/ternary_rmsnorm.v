// =============================================================================
// TERNARY RMS NORM — Shift-Based Approximation for FPGA
// =============================================================================
// No division, no DSP48 — pure shift normalization.
//
//   Pass 1: sum_abs = sum(|x[i]|), store x[i] in buffer
//   Compute: mean_abs = sum_abs >> LOG2_N
//            shift = msb(mean_abs) - FRAC_BITS
//   Pass 2: output[i] = x[i] >> shift (or << if shift negative)
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module ternary_rmsnorm #(
    parameter WIDTH     = 20,
    parameter N         = 243,
    parameter ADDR_W    = 8,
    parameter FRAC_BITS = 8,
    parameter LOG2_N    = 8
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    in_valid,
    input  wire signed [WIDTH-1:0] in_data,
    input  wire [ADDR_W-1:0]       in_addr,
    input  wire                    in_done,
    output reg                     out_valid,
    output reg  signed [WIDTH-1:0] out_data,
    output reg  [ADDR_W-1:0]       out_addr,
    output reg                     out_done
);

    localparam BUF_DEPTH = 256;
    reg signed [WIDTH-1:0] buf_mem [0:BUF_DEPTH-1];

    localparam S_ACCUM = 3'd0;  // Pass 1: accumulate
    localparam S_CALC  = 3'd1;  // Compute mean_abs
    localparam S_SHIFT = 3'd2;  // Compute shift amount
    localparam S_EMIT  = 3'd3;  // Pass 2: emit normalized
    localparam S_DONE  = 3'd4;

    reg [2:0] state;
    reg [WIDTH+ADDR_W-1:0] sum_abs;
    reg [WIDTH-1:0]        mean_abs;
    reg [ADDR_W-1:0]       emit_idx;
    reg [ADDR_W-1:0]       total_count;
    reg [4:0]              shift_amt;
    reg                    shift_left;

    // Priority encoder: find highest set bit
    function [4:0] find_msb;
        input [WIDTH-1:0] val;
        integer k;
        begin
            find_msb = 5'd0;
            for (k = 0; k < WIDTH; k = k + 1)
                if (val[k]) find_msb = k[4:0];
        end
    endfunction

    // Normalize current buffer value
    wire signed [WIDTH-1:0] buf_val;
    assign buf_val = buf_mem[emit_idx];

    wire [WIDTH-1:0] abs_v;
    assign abs_v = buf_val[WIDTH-1] ? (~buf_val + 1) : buf_val;

    wire [WIDTH-1:0] shifted_v;
    assign shifted_v = shift_left ? (abs_v << shift_amt) : (abs_v >> shift_amt);

    // Restore sign
    wire signed [WIDTH-1:0] norm_out;
    assign norm_out = buf_val[WIDTH-1] ? -$signed({1'b0, shifted_v[WIDTH-2:0]}) :
                                          $signed({1'b0, shifted_v[WIDTH-2:0]});

    always @(posedge clk) begin
        if (rst) begin
            state       <= S_ACCUM;
            sum_abs     <= 0;
            mean_abs    <= 0;
            emit_idx    <= 0;
            total_count <= 0;
            shift_amt   <= 5'd0;
            shift_left  <= 1'b0;
            out_valid   <= 1'b0;
            out_done    <= 1'b0;
            out_data    <= 0;
            out_addr    <= 0;
        end else begin
            out_valid <= 1'b0;
            out_done  <= 1'b0;

            case (state)
                // Pass 1: store inputs and accumulate |x[i]|
                S_ACCUM: begin
                    if (in_valid) begin
                        buf_mem[in_addr] <= in_data;
                        if (in_data[WIDTH-1])
                            sum_abs <= sum_abs + {{(ADDR_W){1'b0}}, ~in_data} + 1;
                        else
                            sum_abs <= sum_abs + {{(ADDR_W){1'b0}}, in_data};
                        total_count <= total_count + 1;
                    end
                    if (in_done)
                        state <= S_CALC;
                end

                // Compute mean_abs = sum_abs >> LOG2_N
                S_CALC: begin
                    mean_abs <= sum_abs >> LOG2_N;
                    state    <= S_SHIFT;
                end

                // Compute shift amount from mean_abs
                S_SHIFT: begin
                    if (mean_abs == 0) begin
                        shift_amt  <= FRAC_BITS[4:0];
                        shift_left <= 1'b1;
                    end else begin
                        if (find_msb(mean_abs) >= FRAC_BITS[4:0]) begin
                            shift_amt  <= find_msb(mean_abs) - FRAC_BITS[4:0];
                            shift_left <= 1'b0;
                        end else begin
                            shift_amt  <= FRAC_BITS[4:0] - find_msb(mean_abs);
                            shift_left <= 1'b1;
                        end
                    end
                    emit_idx <= 0;
                    state    <= S_EMIT;
                end

                // Pass 2: emit normalized values
                S_EMIT: begin
                    out_valid <= 1'b1;
                    out_data  <= norm_out;
                    out_addr  <= emit_idx;

                    if (emit_idx == total_count - 1) begin
                        out_done <= 1'b1;
                        state    <= S_DONE;
                    end else begin
                        emit_idx <= emit_idx + 1;
                    end
                end

                S_DONE: state <= S_DONE;

                default: state <= S_DONE;
            endcase
        end
    end

endmodule
