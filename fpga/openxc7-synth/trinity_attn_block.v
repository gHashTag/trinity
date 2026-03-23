//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// TRINITY ATTENTION BLOCK — Attention + FFN Transformer Layer
// =============================================================================
// Full transformer layer: Self-Attention → Residual → FFN → Residual → RMSNorm
//
// Architecture:
//   x → Attention(x) → +x → FFN(y) → +y → RMSNorm → output
//
// Where:
//   Attention = ternary_attention (Q/K/V projection + score + weighted sum)
//   FFN = trinity_block (MatVec→ReLU→MatVec→Residual→RMSNorm)
//
// This creates a "real" transformer layer with both attention and FFN.
// Current hslm_full_top uses FFN-only blocks (no attention).
//
// Resource estimate (1 layer):
//   Attention: ~16 BRAM36, ~2K LUT
//   FFN:       ~32 BRAM36, ~5K LUT
//   Total:     ~48 BRAM36, ~7K LUT, 0 DSP48
//
// For Artix-7 100T (135 BRAM36): fits 2 full layers + embedding + LM head
// For Artix-7 200T (365 BRAM36): fits 6 full layers
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module trinity_attn_block #(
    parameter DIM        = 243,
    parameter HEAD_DIM   = 64,
    parameter CTX_LEN    = 16,
    parameter N_LARGE    = 729,
    parameter ACC_WIDTH  = 20,
    parameter FRAC_BITS  = 8,
    parameter LOG2_CTX   = 4,
    parameter DIM_WIDTH  = 8,
    parameter HD_WIDTH   = 7,
    parameter CTX_WIDTH  = 4,
    parameter ADDR_WIDTH = 18,
    parameter WQ_FILE   = "fpga/weights/attn_wq.mem",
    parameter WK_FILE   = "fpga/weights/attn_wk.mem",
    parameter WV_FILE   = "fpga/weights/attn_wv.mem",
    parameter MEM_FILE_UP   = "fpga/openxc7-synth/ternary_matvec_243x729_weights.mem",
    parameter MEM_FILE_DOWN = "fpga/openxc7-synth/ternary_matvec_729x243_weights.mem"
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    // External input
    output wire [DIM_WIDTH-1:0]               x_rd_addr,
    input  wire signed [ACC_WIDTH-1:0]        x_rd_data,

    // Context position for attention
    input  wire [CTX_WIDTH-1:0]               ctx_pos,

    // Output
    output wire                               out_valid,
    output wire signed [ACC_WIDTH-1:0]        out_data,
    output wire [DIM_WIDTH-1:0]               out_addr,
    output reg                                busy,
    output reg                                done
);

    // =========================================================================
    // INPUT BUFFER
    // =========================================================================
    localparam BUF_DEPTH = 256;
    reg signed [ACC_WIDTH-1:0] input_buf [0:BUF_DEPTH-1];
    reg signed [ACC_WIDTH-1:0] attn_res_buf [0:BUF_DEPTH-1]; // After attention + residual

    // =========================================================================
    // PHASE 1: SELF-ATTENTION
    // =========================================================================
    wire [DIM_WIDTH-1:0]              attn_x_addr;
    wire signed [ACC_WIDTH-1:0]       attn_x_data;
    assign attn_x_data = input_buf[attn_x_addr];

    wire                              attn_out_valid;
    wire signed [ACC_WIDTH-1:0]       attn_out_data;
    wire [DIM_WIDTH-1:0]              attn_out_addr;
    wire                              attn_done;
    wire                              attn_busy;
    reg                               attn_start;

    ternary_attention #(
        .DIM(DIM), .HEAD_DIM(HEAD_DIM), .CTX_LEN(CTX_LEN),
        .ACC_WIDTH(ACC_WIDTH), .FRAC_BITS(FRAC_BITS), .LOG2_CTX(LOG2_CTX),
        .DIM_WIDTH(DIM_WIDTH), .HD_WIDTH(HD_WIDTH), .CTX_WIDTH(CTX_WIDTH),
        .WQ_FILE(WQ_FILE), .WK_FILE(WK_FILE), .WV_FILE(WV_FILE)
    ) attention (
        .clk(clk), .rst(rst), .start(attn_start),
        .x_rd_addr(attn_x_addr), .x_rd_data(attn_x_data),
        .ctx_pos(ctx_pos),
        .out_valid(attn_out_valid), .out_data(attn_out_data),
        .out_addr(attn_out_addr), .done(attn_done), .busy(attn_busy)
    );

    // Attention output + residual → attn_res_buf
    // Note: attention outputs HEAD_DIM values, zero-pad remaining
    always @(posedge clk) begin
        if (attn_out_valid) begin
            // Residual: attention output + input
            attn_res_buf[attn_out_addr] <=
                attn_out_data + input_buf[attn_out_addr];
        end
    end

    // =========================================================================
    // PHASE 2: FFN (TrinityBlock)
    // =========================================================================
    wire [DIM_WIDTH-1:0]              ffn_x_addr;
    wire signed [ACC_WIDTH-1:0]       ffn_x_data;
    assign ffn_x_data = attn_res_buf[ffn_x_addr];

    wire                              ffn_out_valid;
    wire signed [ACC_WIDTH-1:0]       ffn_out_data;
    wire [DIM_WIDTH-1:0]              ffn_out_addr;
    wire                              ffn_done;
    wire                              ffn_busy;
    reg                               ffn_start;

    trinity_block #(
        .N_SMALL(DIM), .N_LARGE(N_LARGE), .ACC_WIDTH(ACC_WIDTH),
        .FRAC_BITS(FRAC_BITS), .ADDR_WIDTH(ADDR_WIDTH),
        .I_UP_WIDTH(DIM_WIDTH), .J_UP_WIDTH(10),
        .I_DOWN_WIDTH(10), .J_DOWN_WIDTH(DIM_WIDTH),
        .MEM_FILE_UP(MEM_FILE_UP), .MEM_FILE_DOWN(MEM_FILE_DOWN)
    ) ffn (
        .clk(clk), .rst(rst), .start(ffn_start),
        .x_rd_addr(ffn_x_addr), .x_rd_data(ffn_x_data),
        .out_valid(ffn_out_valid), .out_data(ffn_out_data),
        .out_addr(ffn_out_addr), .busy(ffn_busy), .done(ffn_done)
    );

    assign out_valid = ffn_out_valid;
    assign out_data  = ffn_out_data;
    assign out_addr  = ffn_out_addr;

    // Read address mux
    assign x_rd_addr = (state == S_FILL) ? fill_idx : {DIM_WIDTH{1'b0}};

    // =========================================================================
    // CONTROL FSM
    // =========================================================================
    localparam S_IDLE     = 3'd0;
    localparam S_FILL     = 3'd1;
    localparam S_ATTN     = 3'd2;
    localparam S_ATTN_WAIT = 3'd3;
    localparam S_FFN      = 3'd4;
    localparam S_FFN_WAIT = 3'd5;
    localparam S_DONE     = 3'd6;

    reg [2:0] state;
    reg [DIM_WIDTH-1:0] fill_idx;

    localparam [DIM_WIDTH-1:0] LAST_DIM = DIM - 1;

    always @(posedge clk) begin
        if (rst) begin
            state      <= S_IDLE;
            busy       <= 1'b0;
            done       <= 1'b0;
            attn_start <= 1'b0;
            ffn_start  <= 1'b0;
            fill_idx   <= {DIM_WIDTH{1'b0}};
        end else begin
            attn_start <= 1'b0;
            ffn_start  <= 1'b0;
            done       <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        busy     <= 1'b1;
                        fill_idx <= {DIM_WIDTH{1'b0}};
                        state    <= S_FILL;
                    end
                end

                // Fill input buffer from external source
                S_FILL: begin
                    input_buf[fill_idx] <= x_rd_data;
                    if (fill_idx == LAST_DIM) begin
                        state <= S_ATTN;
                    end else begin
                        fill_idx <= fill_idx + 1'b1;
                    end
                end

                // Start attention
                S_ATTN: begin
                    attn_start <= 1'b1;
                    state      <= S_ATTN_WAIT;
                end

                S_ATTN_WAIT: begin
                    if (attn_done) begin
                        // Zero-fill remaining dimensions (attention outputs HEAD_DIM < DIM)
                        state <= S_FFN;
                    end
                end

                // Start FFN
                S_FFN: begin
                    ffn_start <= 1'b1;
                    state     <= S_FFN_WAIT;
                end

                S_FFN_WAIT: begin
                    if (ffn_done) begin
                        state <= S_DONE;
                    end
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
