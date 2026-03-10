// =============================================================================
// EMBEDDING LOOKUP — BRAM-Based Token Embedding Table
// =============================================================================
// Given a token_id [0..VOCAB-1], streams out DIM embedding values.
//
// Architecture:
//   - Embedding table stored in BRAM: VOCAB x DIM x DATA_WIDTH
//   - Sequential read: for each token, reads DIM consecutive entries
//   - Memory layout: row-major, addr = token_id * DIM + k
//   - Pre-computed base_addr avoids multiplication (shifted at init)
//   - Power-of-2 BRAM depth for clean Yosys cascade decode
//
// Default: VOCAB=256, DIM=243, DATA_WIDTH=20
//   - 256 x 243 = 62,208 entries x 20 bits = ~152 KB = ~4 BRAM36
//   - BRAM declared as 2^16 = 65,536 entries (power-of-2)
//   - Latency: DIM + 2 clocks = ~245 clocks = 4.9 us @ 50 MHz
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module embedding_lookup #(
    parameter VOCAB      = 256,
    parameter DIM        = 243,
    parameter DATA_WIDTH = 20,
    parameter ADDR_WIDTH = 16,   // 2^16 = 65536 >= 256*243 = 62208
    parameter TOK_WIDTH  = 8,    // ceil(log2(VOCAB))
    parameter DIM_WIDTH  = 8,    // ceil(log2(DIM))
    parameter MEM_FILE   = "fpga/weights/embedding_weights.mem"
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
    // EMBEDDING MEMORY — BRAM (inferred by Yosys)
    // =========================================================================
    localparam MEM_DEPTH = 1 << ADDR_WIDTH;  // 65536 (power-of-2)

    reg signed [DATA_WIDTH-1:0] emb_mem [0:MEM_DEPTH-1];
    initial $readmemh(MEM_FILE, emb_mem);

    reg [ADDR_WIDTH-1:0] rd_addr;
    reg signed [DATA_WIDTH-1:0] rd_data_r;

    // Registered BRAM read — 1 clock latency
    always @(posedge clk) begin
        rd_data_r <= emb_mem[rd_addr];
    end

    // =========================================================================
    // INDEX COUNTERS
    // =========================================================================
    reg [DIM_WIDTH-1:0] k_idx;         // output dimension counter [0..DIM-1]
    reg [ADDR_WIDTH-1:0] base_addr;    // token_id * DIM (pre-computed)

    localparam [DIM_WIDTH-1:0] LAST_K = DIM - 1;

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    localparam S_IDLE     = 3'd0;
    localparam S_CALC     = 3'd1;   // compute base_addr = token_id * DIM
    localparam S_PREFETCH = 3'd2;   // wait for first BRAM read
    localparam S_STREAM   = 3'd3;   // stream DIM values
    localparam S_LAST     = 3'd4;   // emit final value
    localparam S_DONE     = 3'd5;

    reg [2:0] state;

    // Base address calculation: token_id * 243
    // 243 = 256 - 16 + 4 - 1 = 2^8 - 2^4 + 2^2 - 2^0
    // But simpler: 243 = 3 * 81 = 3 * 3^4
    // Use shift-add: 243 = 256 - 13 = (token_id << 8) - (token_id << 4) + (token_id << 2) - token_id
    // Actually 256-16+4-1 = 243. Let's verify: 256-16=240, 240+4=244, 244-1=243. Yes!
    wire [ADDR_WIDTH-1:0] tok_ext = {{(ADDR_WIDTH-TOK_WIDTH){1'b0}}, token_id};
    wire [ADDR_WIDTH-1:0] base_addr_calc =
        (tok_ext << 8) - (tok_ext << 4) + (tok_ext << 2) - tok_ext;

    // Pipeline: registered output address (1 cycle behind rd_data_r)
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

                // Set up first BRAM read address
                S_CALC: begin
                    rd_addr <= base_addr;
                    state   <= S_PREFETCH;
                end

                // Wait 1 clock for BRAM data, prepare k=1 address
                S_PREFETCH: begin
                    k_out_d1 <= {DIM_WIDTH{1'b0}};  // k=0 will appear in rd_data_r next cycle
                    k_idx    <= {{(DIM_WIDTH-1){1'b0}}, 1'b1};  // advance to k=1
                    rd_addr  <= base_addr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
                    state    <= S_STREAM;
                end

                // Stream: emit rd_data_r (for previous k), advance k
                S_STREAM: begin
                    out_data  <= rd_data_r;
                    out_addr  <= k_out_d1;
                    out_valid <= 1'b1;
                    k_out_d1  <= k_idx;

                    if (k_idx == LAST_K) begin
                        // Last read issued, one more output pending
                        state <= S_LAST;
                    end else begin
                        k_idx   <= k_idx + {{(DIM_WIDTH-1){1'b0}}, 1'b1};
                        rd_addr <= base_addr + {{(ADDR_WIDTH - DIM_WIDTH - 1){1'b0}}, k_idx} + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
                    end
                end

                // Emit the final value
                S_LAST: begin
                    out_data  <= rd_data_r;
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
