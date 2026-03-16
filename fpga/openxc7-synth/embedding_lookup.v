// =============================================================================
// EMBEDDING LOOKUP — BRAM-Based Ternary Token Embedding Table
// =============================================================================
// Given a token_id [0..VOCAB-1], streams out DIM signed embedding values.
//
// Architecture:
//   - Embedding table stored in BRAM as 2-bit ternary codes
//   - 01 = +1, 10 = -1, 00 = 0 (same encoding as weight matrices)
//   - Output: signed DATA_WIDTH values (sign-extended from ternary)
//   - Sequential read: for each token, reads DIM consecutive codes
//   - Memory layout: row-major, addr = token_id * DIM + k
//   - Power-of-2 BRAM depth for clean Yosys cascade decode
//
// Default: VOCAB=128, DIM=243
//   - 128 x 243 = 31,104 entries x 2 bits = ~7.6 KB ≈ 0.2 BRAM36
//   - BRAM declared as 2^15 = 32,768 entries (power-of-2)
//   - Latency: DIM + 2 clocks = ~245 clocks = 4.9 us @ 50 MHz
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module embedding_lookup #(
    parameter VOCAB      = 128,
    parameter DIM        = 243,
    parameter DATA_WIDTH = 20,
    parameter ADDR_WIDTH = 15,   // 2^15 = 32768 >= 128*243 = 31104
    parameter TOK_WIDTH  = 7,    // ceil(log2(VOCAB))
    parameter DIM_WIDTH  = 8,    // ceil(log2(DIM))
    parameter MEM_FILE   = "embedding_weights.mem"
)(
    input  wire                       clk,
    input  wire                       rst,
    input  wire                       start,
    input  wire [TOK_WIDTH-1:0]       token_id,

    output reg signed [DATA_WIDTH-1:0] out_data,
    output reg  [DIM_WIDTH-1:0]        out_addr,
    output reg                         out_valid,
    output reg                         done,
    output reg                         busy
);

    // =========================================================================
    // EMBEDDING MEMORY — BRAM (2-bit ternary codes)
    // =========================================================================
    localparam MEM_DEPTH = 1 << ADDR_WIDTH;  // 32768 (power-of-2)

    (* ram_style = "block" *)
    reg [1:0] emb_mem [0:MEM_DEPTH-1];
    initial $readmemb(MEM_FILE, emb_mem);

    reg [ADDR_WIDTH-1:0] rd_addr;
    reg [1:0] code_r;

    // Registered BRAM read — 1 clock latency
    always @(posedge clk) begin
        code_r <= emb_mem[rd_addr];
    end

    // Ternary code → signed value
    // 01 → +1, 10 → -1, 00/11 → 0
    wire signed [DATA_WIDTH-1:0] decoded_val =
        (code_r == 2'b01) ? {{(DATA_WIDTH-1){1'b0}}, 1'b1} :
        (code_r == 2'b10) ? {DATA_WIDTH{1'b1}} :  // -1 in two's complement
        {DATA_WIDTH{1'b0}};

    // =========================================================================
    // INDEX COUNTERS
    // =========================================================================
    reg [DIM_WIDTH-1:0] k_idx;
    reg [ADDR_WIDTH-1:0] base_addr;

    localparam [DIM_WIDTH-1:0] LAST_K = DIM - 1;

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    localparam S_IDLE     = 3'd0;
    localparam S_CALC     = 3'd1;
    localparam S_PREFETCH = 3'd2;
    localparam S_STREAM   = 3'd3;
    localparam S_LAST     = 3'd4;
    localparam S_DONE     = 3'd5;

    reg [2:0] state;

    // Base address: token_id * 243
    // 243 = 256 - 16 + 4 - 1 = (tok<<8) - (tok<<4) + (tok<<2) - tok
    wire [ADDR_WIDTH-1:0] tok_ext = {{(ADDR_WIDTH-TOK_WIDTH){1'b0}}, token_id};
    wire [ADDR_WIDTH-1:0] base_addr_calc =
        (tok_ext << 8) - (tok_ext << 4) + (tok_ext << 2) - tok_ext;

    reg [DIM_WIDTH-1:0] k_out_d1;

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            k_idx     <= {DIM_WIDTH{1'b0}};
            base_addr <= {ADDR_WIDTH{1'b0}};
            rd_addr   <= {ADDR_WIDTH{1'b0}};
            k_out_d1  <= {DIM_WIDTH{1'b0}};
            out_data  <= {DATA_WIDTH{1'b0}};
            out_addr  <= {DIM_WIDTH{1'b0}};
            out_valid <= 1'b0;
            done      <= 1'b0;
            busy      <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            done      <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        busy      <= 1'b1;
                        base_addr <= base_addr_calc;
                        k_idx     <= {DIM_WIDTH{1'b0}};
                        state     <= S_CALC;
                    end
                end

                S_CALC: begin
                    rd_addr <= base_addr;
                    state   <= S_PREFETCH;
                end

                S_PREFETCH: begin
                    k_out_d1 <= {DIM_WIDTH{1'b0}};
                    k_idx    <= {{(DIM_WIDTH-1){1'b0}}, 1'b1};
                    rd_addr  <= base_addr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
                    state    <= S_STREAM;
                end

                S_STREAM: begin
                    out_data  <= decoded_val;
                    out_addr  <= k_out_d1;
                    out_valid <= 1'b1;
                    k_out_d1  <= k_idx;

                    if (k_idx == LAST_K) begin
                        state <= S_LAST;
                    end else begin
                        k_idx   <= k_idx + {{(DIM_WIDTH-1){1'b0}}, 1'b1};
                        rd_addr <= base_addr + {{(ADDR_WIDTH - DIM_WIDTH - 1){1'b0}}, k_idx} + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
                    end
                end

                S_LAST: begin
                    out_data  <= decoded_val;
                    out_addr  <= k_out_d1;
                    out_valid <= 1'b1;
                    state     <= S_DONE;
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
