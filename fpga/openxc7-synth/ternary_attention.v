// =============================================================================
// TERNARY ATTENTION — Self-Attention for Ternary Transformer on FPGA
// =============================================================================
// Implements single-head self-attention with ternary weights:
//   Q = Wq * x    (DIM → HEAD_DIM)
//   K = Wk * x    (DIM → HEAD_DIM)
//   V = Wv * x    (DIM → HEAD_DIM)
//   scores[i][j] = Q[i] * K[j]  (dot product, no softmax)
//   out[i] = sum_j scores[i][j] * V[j]  (weighted sum)
//
// Key design decisions:
//   - No softmax: use shift-based normalization (>>log2(CTX))
//   - Single head to fit BRAM budget
//   - Sequential Q/K/V projection reusing one MatVec unit
//   - Context window: CTX_LEN tokens (stored in BRAM)
//
// Parameters:
//   DIM      = 243 (input/output dimension)
//   HEAD_DIM = 64  (attention head dimension)
//   CTX_LEN  = 16  (context window, limited by BRAM)
//
// Resources (estimated):
//   - Wq/Wk/Wv: 3 * 243*64 * 2 bits = ~11.4 KB = ~3 BRAM36
//   - K/V cache: 2 * 16*64 * 20 bits = ~40 KB = ~10 BRAM36
//   - Score buffer: 16*16 * 20 bits = ~10 KB = ~2.5 BRAM36
//   - Total: ~16 BRAM36, ~2K LUT, 0 DSP48
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module ternary_attention #(
    parameter DIM       = 243,
    parameter HEAD_DIM  = 64,
    parameter CTX_LEN   = 16,
    parameter ACC_WIDTH  = 20,
    parameter FRAC_BITS  = 8,
    parameter LOG2_CTX   = 4,     // log2(CTX_LEN) for normalization shift
    parameter DIM_WIDTH  = 8,     // ceil(log2(DIM))
    parameter HD_WIDTH   = 7,     // ceil(log2(HEAD_DIM))
    parameter CTX_WIDTH  = 4,     // ceil(log2(CTX_LEN))
    parameter WQ_FILE   = "fpga/weights/attn_wq.mem",
    parameter WK_FILE   = "fpga/weights/attn_wk.mem",
    parameter WV_FILE   = "fpga/weights/attn_wv.mem"
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    // Input: read from external buffer
    output reg  [DIM_WIDTH-1:0]              x_rd_addr,
    input  wire signed [ACC_WIDTH-1:0]       x_rd_data,

    // Context position (0..CTX_LEN-1): which slot to store Q/K/V
    input  wire [CTX_WIDTH-1:0]              ctx_pos,

    // Output: attention result (DIM values, streamed)
    output reg                               out_valid,
    output reg  signed [ACC_WIDTH-1:0]       out_data,
    output reg  [DIM_WIDTH-1:0]              out_addr,
    output reg                               done,
    output reg                               busy
);

    // =========================================================================
    // WEIGHT MEMORIES — Wq, Wk, Wv (ternary, 2-bit per weight)
    // =========================================================================
    // Layout: row-major, addr = head_dim_idx * DIM + dim_idx
    localparam W_DEPTH = 1 << 14;  // 16384 >= 64*243 = 15552

    reg [1:0] wq_mem [0:W_DEPTH-1];
    reg [1:0] wk_mem [0:W_DEPTH-1];
    reg [1:0] wv_mem [0:W_DEPTH-1];

    initial begin
        $readmemb(WQ_FILE, wq_mem);
        $readmemb(WK_FILE, wk_mem);
        $readmemb(WV_FILE, wv_mem);
    end

    // =========================================================================
    // K/V CACHE — stores projected K and V for all context positions
    // =========================================================================
    // K cache: CTX_LEN * HEAD_DIM entries
    // V cache: CTX_LEN * HEAD_DIM entries
    localparam KV_DEPTH = CTX_LEN * HEAD_DIM;  // 16 * 64 = 1024

    reg signed [ACC_WIDTH-1:0] k_cache [0:KV_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] v_cache [0:KV_DEPTH-1];

    // =========================================================================
    // Q/K/V PROJECTION BUFFERS
    // =========================================================================
    reg signed [ACC_WIDTH-1:0] q_buf [0:HEAD_DIM-1];
    reg signed [ACC_WIDTH-1:0] proj_buf [0:HEAD_DIM-1];  // temp for K or V

    // =========================================================================
    // ATTENTION SCORE BUFFER
    // =========================================================================
    reg signed [ACC_WIDTH-1:0] scores [0:CTX_LEN-1];

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    localparam S_IDLE       = 4'd0;
    localparam S_PROJ_Q     = 4'd1;   // Q = Wq * x
    localparam S_PROJ_K     = 4'd2;   // K = Wk * x, store in cache
    localparam S_PROJ_V     = 4'd3;   // V = Wv * x, store in cache
    localparam S_SCORE      = 4'd4;   // scores[j] = Q . K_cache[j]
    localparam S_NORM       = 4'd5;   // scores[j] >>= LOG2_CTX (approx softmax)
    localparam S_WEIGHTED   = 4'd6;   // out[d] = sum_j scores[j] * V_cache[j][d]
    localparam S_OUTPUT     = 4'd7;   // Stream output
    localparam S_DONE       = 4'd8;

    reg [3:0]  state;
    reg [1:0]  proj_phase;  // 0=Q, 1=K, 2=V

    // Projection counters
    reg [HD_WIDTH-1:0]  hd_idx;   // head dim index [0..HEAD_DIM-1]
    reg [DIM_WIDTH-1:0] d_idx;    // input dim index [0..DIM-1]
    reg [13:0]          w_addr;   // weight memory address
    reg signed [ACC_WIDTH-1:0] acc;

    // Score/weighted sum counters
    reg [CTX_WIDTH-1:0] j_idx;    // context index
    reg [HD_WIDTH-1:0]  k_idx;    // head dim for dot product
    reg signed [ACC_WIDTH-1:0] dot_acc;

    // Output buffer
    reg signed [ACC_WIDTH-1:0] out_buf [0:HEAD_DIM-1];

    // Input buffer (latched during projection)
    reg signed [ACC_WIDTH-1:0] x_buf [0:255];
    reg [DIM_WIDTH-1:0] fill_idx;

    // Weight read pipeline
    reg [1:0] w_code;

    always @(posedge clk) begin
        if (rst) begin
            state      <= S_IDLE;
            busy       <= 1'b0;
            done       <= 1'b0;
            out_valid  <= 1'b0;
            proj_phase <= 2'd0;
            hd_idx     <= {HD_WIDTH{1'b0}};
            d_idx      <= {DIM_WIDTH{1'b0}};
            acc        <= {ACC_WIDTH{1'b0}};
        end else begin
            done      <= 1'b0;
            out_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        busy       <= 1'b1;
                        fill_idx   <= {DIM_WIDTH{1'b0}};
                        x_rd_addr  <= {DIM_WIDTH{1'b0}};
                        proj_phase <= 2'd0;
                        hd_idx     <= {HD_WIDTH{1'b0}};
                        d_idx      <= {DIM_WIDTH{1'b0}};
                        acc        <= {ACC_WIDTH{1'b0}};
                        state      <= S_PROJ_Q;
                    end
                end

                // ─── Q PROJECTION: q[h] = sum_d Wq[h][d] * x[d] ───
                S_PROJ_Q: begin
                    w_addr <= {hd_idx, d_idx[DIM_WIDTH-1:0]};
                    w_code <= wq_mem[{hd_idx, d_idx[DIM_WIDTH-1:0]}];

                    // Read input
                    x_rd_addr <= d_idx;

                    // Accumulate (1 cycle delay for BRAM, simplified here)
                    case (w_code)
                        2'b01: acc <= acc + x_rd_data;   // +1
                        2'b10: acc <= acc - x_rd_data;   // -1
                        default: ;                       // 0
                    endcase

                    if (d_idx == DIM[DIM_WIDTH-1:0] - 1) begin
                        q_buf[hd_idx] <= acc;
                        acc <= {ACC_WIDTH{1'b0}};
                        d_idx <= {DIM_WIDTH{1'b0}};
                        if (hd_idx == HEAD_DIM[HD_WIDTH-1:0] - 1) begin
                            hd_idx <= {HD_WIDTH{1'b0}};
                            state  <= S_PROJ_K;
                        end else
                            hd_idx <= hd_idx + 1'b1;
                    end else
                        d_idx <= d_idx + 1'b1;
                end

                // ─── K PROJECTION: k[h] = sum_d Wk[h][d] * x[d] ───
                S_PROJ_K: begin
                    w_code <= wk_mem[{hd_idx, d_idx[DIM_WIDTH-1:0]}];
                    x_rd_addr <= d_idx;

                    case (w_code)
                        2'b01: acc <= acc + x_rd_data;
                        2'b10: acc <= acc - x_rd_data;
                        default: ;
                    endcase

                    if (d_idx == DIM[DIM_WIDTH-1:0] - 1) begin
                        // Store K in cache at current context position
                        k_cache[{ctx_pos, hd_idx}] <= acc;
                        acc <= {ACC_WIDTH{1'b0}};
                        d_idx <= {DIM_WIDTH{1'b0}};
                        if (hd_idx == HEAD_DIM[HD_WIDTH-1:0] - 1) begin
                            hd_idx <= {HD_WIDTH{1'b0}};
                            state  <= S_PROJ_V;
                        end else
                            hd_idx <= hd_idx + 1'b1;
                    end else
                        d_idx <= d_idx + 1'b1;
                end

                // ─── V PROJECTION: v[h] = sum_d Wv[h][d] * x[d] ───
                S_PROJ_V: begin
                    w_code <= wv_mem[{hd_idx, d_idx[DIM_WIDTH-1:0]}];
                    x_rd_addr <= d_idx;

                    case (w_code)
                        2'b01: acc <= acc + x_rd_data;
                        2'b10: acc <= acc - x_rd_data;
                        default: ;
                    endcase

                    if (d_idx == DIM[DIM_WIDTH-1:0] - 1) begin
                        v_cache[{ctx_pos, hd_idx}] <= acc;
                        acc <= {ACC_WIDTH{1'b0}};
                        d_idx <= {DIM_WIDTH{1'b0}};
                        if (hd_idx == HEAD_DIM[HD_WIDTH-1:0] - 1) begin
                            hd_idx <= {HD_WIDTH{1'b0}};
                            j_idx  <= {CTX_WIDTH{1'b0}};
                            k_idx  <= {HD_WIDTH{1'b0}};
                            dot_acc <= {ACC_WIDTH{1'b0}};
                            state  <= S_SCORE;
                        end else
                            hd_idx <= hd_idx + 1'b1;
                    end else
                        d_idx <= d_idx + 1'b1;
                end

                // ─── ATTENTION SCORES: scores[j] = Q . K_cache[j] ───
                S_SCORE: begin
                    // Dot product: sum over head_dim
                    dot_acc <= dot_acc +
                        (q_buf[k_idx] * k_cache[{j_idx, k_idx}]) >>> FRAC_BITS;

                    if (k_idx == HEAD_DIM[HD_WIDTH-1:0] - 1) begin
                        scores[j_idx] <= dot_acc +
                            (q_buf[k_idx] * k_cache[{j_idx, k_idx}]) >>> FRAC_BITS;
                        dot_acc <= {ACC_WIDTH{1'b0}};
                        k_idx   <= {HD_WIDTH{1'b0}};
                        if (j_idx == ctx_pos) begin
                            // All scores computed up to current position
                            j_idx <= {CTX_WIDTH{1'b0}};
                            state <= S_NORM;
                        end else
                            j_idx <= j_idx + 1'b1;
                    end else
                        k_idx <= k_idx + 1'b1;
                end

                // ─── NORMALIZE: shift-based approx (scores >> LOG2_CTX) ───
                S_NORM: begin
                    scores[j_idx] <= scores[j_idx] >>> LOG2_CTX;
                    if (j_idx == ctx_pos) begin
                        j_idx  <= {CTX_WIDTH{1'b0}};
                        k_idx  <= {HD_WIDTH{1'b0}};
                        dot_acc <= {ACC_WIDTH{1'b0}};
                        state  <= S_WEIGHTED;
                    end else
                        j_idx <= j_idx + 1'b1;
                end

                // ─── WEIGHTED SUM: out[h] = sum_j scores[j] * V_cache[j][h] ───
                S_WEIGHTED: begin
                    dot_acc <= dot_acc +
                        (scores[j_idx] * v_cache[{j_idx, k_idx}]) >>> FRAC_BITS;

                    if (j_idx == ctx_pos) begin
                        out_buf[k_idx] <= dot_acc +
                            (scores[j_idx] * v_cache[{j_idx, k_idx}]) >>> FRAC_BITS;
                        dot_acc <= {ACC_WIDTH{1'b0}};
                        j_idx   <= {CTX_WIDTH{1'b0}};
                        if (k_idx == HEAD_DIM[HD_WIDTH-1:0] - 1) begin
                            hd_idx <= {HD_WIDTH{1'b0}};
                            state  <= S_OUTPUT;
                        end else
                            k_idx <= k_idx + 1'b1;
                    end else
                        j_idx <= j_idx + 1'b1;
                end

                // ─── STREAM OUTPUT ───
                S_OUTPUT: begin
                    out_valid <= 1'b1;
                    out_data  <= out_buf[hd_idx];
                    out_addr  <= {{(DIM_WIDTH - HD_WIDTH){1'b0}}, hd_idx};

                    if (hd_idx == HEAD_DIM[HD_WIDTH-1:0] - 1) begin
                        state <= S_DONE;
                    end else
                        hd_idx <= hd_idx + 1'b1;
                end

                S_DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
