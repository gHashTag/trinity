// ═══════════════════════════════════════════════════════════════════════════════
// HSLM TERNARY MAC — Zero-DSP Inference Engine for Artix-7
// ═══════════════════════════════════════════════════════════════════════════════
//
// Key insight: ternary weights {-1, 0, +1} eliminate ALL multiplications.
//   +1 × input = input      (wire)
//   -1 × input = -input     (inverter, 1 LUT)
//    0 × input = 0          (nothing)
//
// Resources per neuron: ~3 LUT per weight (MUX + negate)
// 64 parallel neurons × 243 weights = ~62K LUT (fits Artix-7 XC7A100T)
//
// Weight encoding: 2 bits per weight
//   00 = 0 (zero)
//   01 = +1 (positive)
//   11 = -1 (negative)
//   10 = reserved (treated as 0)
//
// Architecture: HSLM 1.95M params
//   Vocab=729(3^6) | Embed=243(3^5) | Hidden=729(3^6)
//   Blocks=3 | Heads=3 | Context=81(3^4)
//
// Target: 5,000 tokens/sec @ 100MHz on $50 QMtech board
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

`default_nettype none

// ─────────────────────────────────────────────────────────────────────────────
// MODULE 1: Single Ternary MAC Unit
// Accumulates: acc += weight × input over N_INPUTS clock cycles
// 0 DSP — pure LUT logic
// ─────────────────────────────────────────────────────────────────────────────
module ternary_mac_unit #(
    parameter INPUT_WIDTH = 16,   // fixed-point input width (Q8.8)
    parameter ACC_WIDTH   = 32,   // accumulator width (enough for 729 inputs)
    parameter N_INPUTS    = 243   // weights per neuron
)(
    input  wire                        clk,
    input  wire                        rst,
    input  wire                        valid,
    input  wire signed [INPUT_WIDTH-1:0] input_val,
    input  wire [1:0]                  weight,   // 00=0, 01=+1, 11=-1
    output reg  signed [ACC_WIDTH-1:0] accumulator,
    output reg                         done
);
    reg [$clog2(N_INPUTS)-1:0] count;

    // Ternary MUX: 0 DSP, ~3 LUT
    // weight=01 → +input, weight=11 → -input, else → 0
    wire signed [INPUT_WIDTH:0] mac_val =
        (weight == 2'b01) ?  { input_val[INPUT_WIDTH-1], input_val } :  // +1: sign-extend
        (weight == 2'b11) ? -{ input_val[INPUT_WIDTH-1], input_val } :  // -1: negate
                             {(INPUT_WIDTH+1){1'b0}};                    //  0: zero

    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 0;
            count       <= 0;
            done        <= 0;
        end else if (valid) begin
            accumulator <= accumulator + {{(ACC_WIDTH-INPUT_WIDTH-1){mac_val[INPUT_WIDTH]}}, mac_val};
            if (count == N_INPUTS - 1) begin
                done  <= 1;
                count <= 0;
            end else begin
                count <= count + 1;
                done  <= 0;
            end
        end else begin
            done <= 0;
        end
    end
endmodule

// ─────────────────────────────────────────────────────────────────────────────
// MODULE 2: Parallel MAC Array (N_PARALLEL neurons computed simultaneously)
// Processes one input value per clock, broadcasts to all neurons
// Each neuron has its own weight → different column of weight matrix
// ─────────────────────────────────────────────────────────────────────────────
module ternary_mac_array #(
    parameter N_PARALLEL  = 64,   // neurons computed in parallel
    parameter N_INPUTS    = 243,  // inputs per neuron
    parameter INPUT_WIDTH = 16,   // Q8.8 fixed-point
    parameter ACC_WIDTH   = 32
)(
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              valid,
    input  wire signed [INPUT_WIDTH-1:0]     input_val,       // broadcast to all MACs
    input  wire [2*N_PARALLEL-1:0]           weights_packed,  // 64 × 2-bit weights
    output wire [N_PARALLEL-1:0]             done,
    output wire signed [ACC_WIDTH-1:0]       results [0:N_PARALLEL-1]
);
    genvar i;
    generate
        for (i = 0; i < N_PARALLEL; i = i + 1) begin : mac_units
            ternary_mac_unit #(
                .INPUT_WIDTH(INPUT_WIDTH),
                .ACC_WIDTH(ACC_WIDTH),
                .N_INPUTS(N_INPUTS)
            ) unit (
                .clk(clk),
                .rst(rst),
                .valid(valid),
                .input_val(input_val),
                .weight(weights_packed[2*i+1 : 2*i]),
                .accumulator(results[i]),
                .done(done[i])
            );
        end
    endgenerate
endmodule

// ─────────────────────────────────────────────────────────────────────────────
// MODULE 3: BRAM Weight Store
// Stores 2-bit packed weights for one layer in BRAM
// Read interface: given (row, col_group), outputs 64 × 2-bit weights
//
// Memory layout: weights[row][col_group] = 128-bit word (64 weights × 2 bits)
// Total BRAM for embed→hidden (243×729):
//   729 cols / 64 = 12 groups, 243 rows × 12 = 2,916 words × 128 bits
//   = 373 Kbit ≈ 11 BRAM36 (of 135 available)
// ─────────────────────────────────────────────────────────────────────────────
module weight_bram #(
    parameter N_ROWS       = 243,   // input dimension
    parameter N_COLS       = 729,   // output dimension
    parameter N_PARALLEL   = 64,    // weights read per cycle
    parameter ADDR_WIDTH   = 12     // ceil(log2(N_ROWS × ceil(N_COLS/N_PARALLEL)))
)(
    input  wire                          clk,
    input  wire                          we,
    input  wire [ADDR_WIDTH-1:0]         waddr,
    input  wire [2*N_PARALLEL-1:0]       wdata,     // write: 64 × 2-bit weights
    input  wire [ADDR_WIDTH-1:0]         raddr,
    output reg  [2*N_PARALLEL-1:0]       rdata      // read: 64 × 2-bit weights
);
    // BRAM inference — synthesizer maps to Block RAM
    (* ram_style = "block" *)
    reg [2*N_PARALLEL-1:0] mem [0:(1 << ADDR_WIDTH)-1];

    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
        rdata <= mem[raddr];
    end
endmodule

// ─────────────────────────────────────────────────────────────────────────────
// MODULE 4: Layer Controller — orchestrates one matmul: y = W × x
// Feeds input values one by one, reads weight groups from BRAM,
// collects results from MAC array, writes output to buffer
//
// Timing: N_ROWS cycles per group × ceil(N_COLS/N_PARALLEL) groups
// For 243→729: 243 × 12 = 2,916 cycles = 29 µs @ 100 MHz
// ─────────────────────────────────────────────────────────────────────────────
module layer_controller #(
    parameter N_ROWS      = 243,
    parameter N_COLS      = 729,
    parameter N_PARALLEL  = 64,
    parameter INPUT_WIDTH = 16,
    parameter ACC_WIDTH   = 32
)(
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          start,        // pulse to begin computation
    input  wire signed [INPUT_WIDTH-1:0] input_buf [0:N_ROWS-1],  // input vector
    output reg  signed [ACC_WIDTH-1:0]   output_buf [0:N_COLS-1], // output vector
    output reg                           done,

    // BRAM interface
    output reg  [$clog2(N_ROWS * ((N_COLS + N_PARALLEL - 1) / N_PARALLEL))-1:0] bram_addr,
    input  wire [2*N_PARALLEL-1:0]       bram_data
);

    localparam N_GROUPS = (N_COLS + N_PARALLEL - 1) / N_PARALLEL;  // ceil division
    localparam TOTAL_CYCLES = N_ROWS * N_GROUPS;

    // State machine
    localparam S_IDLE    = 2'd0;
    localparam S_COMPUTE = 2'd1;
    localparam S_STORE   = 2'd2;
    localparam S_DONE    = 2'd3;

    reg [1:0] state;
    reg [$clog2(N_ROWS)-1:0]   row_cnt;
    reg [$clog2(N_GROUPS)-1:0] grp_cnt;

    // MAC array signals
    wire mac_valid = (state == S_COMPUTE);
    wire signed [INPUT_WIDTH-1:0] mac_input = input_buf[row_cnt];
    wire [N_PARALLEL-1:0] mac_done;
    wire signed [ACC_WIDTH-1:0] mac_results [0:N_PARALLEL-1];

    // MAC array reset between groups
    wire mac_rst = rst | (state == S_STORE);

    ternary_mac_array #(
        .N_PARALLEL(N_PARALLEL),
        .N_INPUTS(N_ROWS),
        .INPUT_WIDTH(INPUT_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) mac_array (
        .clk(clk),
        .rst(mac_rst),
        .valid(mac_valid),
        .input_val(mac_input),
        .weights_packed(bram_data),
        .done(mac_done),
        .results(mac_results)
    );

    // BRAM address: row * N_GROUPS + grp
    always @(*) begin
        bram_addr = row_cnt * N_GROUPS + grp_cnt;
    end

    // State machine
    always @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            row_cnt <= 0;
            grp_cnt <= 0;
            done    <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        state   <= S_COMPUTE;
                        row_cnt <= 0;
                        grp_cnt <= 0;
                    end
                end

                S_COMPUTE: begin
                    if (row_cnt == N_ROWS - 1) begin
                        // Done with this group — store results
                        state <= S_STORE;
                    end else begin
                        row_cnt <= row_cnt + 1;
                    end
                end

                S_STORE: begin
                    // Copy MAC results to output buffer
                    // (handled by output logic below)
                    row_cnt <= 0;
                    if (grp_cnt == N_GROUPS - 1) begin
                        state <= S_DONE;
                    end else begin
                        grp_cnt <= grp_cnt + 1;
                        state   <= S_COMPUTE;
                    end
                end

                S_DONE: begin
                    done  <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end

    // Store MAC results into output buffer when group completes
    integer k;
    always @(posedge clk) begin
        if (state == S_STORE) begin
            for (k = 0; k < N_PARALLEL; k = k + 1) begin
                if (grp_cnt * N_PARALLEL + k < N_COLS) begin
                    output_buf[grp_cnt * N_PARALLEL + k] <= mac_results[k];
                end
            end
        end
    end

endmodule

// ─────────────────────────────────────────────────────────────────────────────
// MODULE 5: HSLM Inference Top — Full forward pass
// Chain: embed → [attention → FFN] × 3 → output projection
//
// Resource budget (Artix-7 XC7A100T):
//   LUT:  ~62K / 63.4K (98%) — MAC array + control
//   BRAM: ~109 / 135 (81%) — all weights 2-bit packed
//   DSP:  ~20 / 240 (8%) — softmax/layernorm only
//   FF:   ~8K / 126.8K (6%) — pipeline regs + control
//
// Performance @ 100MHz:
//   Per layer: 243 cycles × 12 groups = 2,916 cycles = 29 µs
//   6 layers: 175 µs
//   + softmax/embed/output: ~25 µs
//   Total: ~200 µs per token = 5,000 tokens/sec
// ─────────────────────────────────────────────────────────────────────────────
module hslm_inference_top #(
    parameter VOCAB_DIM   = 729,   // 3^6 — vocabulary
    parameter EMBED_DIM   = 243,   // 3^5 — embedding
    parameter HIDDEN_DIM  = 729,   // 3^6 — hidden (FFN)
    parameter N_BLOCKS    = 3,     // transformer blocks
    parameter N_HEADS     = 3,     // attention heads
    parameter CONTEXT_LEN = 81,    // 3^4 — context window
    parameter N_PARALLEL  = 64,    // parallel MAC units
    parameter INPUT_WIDTH = 16,    // Q8.8 fixed-point
    parameter ACC_WIDTH   = 32
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [9:0]  token_id,       // input token (0..728)
    output reg  [9:0]  output_token,   // predicted next token
    output reg         done,
    output reg         busy,

    // BRAM interface (directly connected to weight memory)
    output wire [15:0] weight_addr,
    input  wire [2*N_PARALLEL-1:0] weight_data,

    // Optional: UART output for debug
    output wire [7:0]  debug_byte,
    output wire        debug_valid
);

    // State machine
    localparam S_IDLE       = 4'd0;
    localparam S_EMBED      = 4'd1;   // lookup embedding
    localparam S_ATTN_QKV   = 4'd2;   // compute Q, K, V projections
    localparam S_ATTN_SCORE = 4'd3;   // attention scores (Q × K^T)
    localparam S_ATTN_APPLY = 4'd4;   // apply attention (scores × V)
    localparam S_ATTN_OUT   = 4'd5;   // output projection
    localparam S_FFN_UP     = 4'd6;   // FFN up projection (243→729)
    localparam S_FFN_DOWN   = 4'd7;   // FFN down projection (729→243)
    localparam S_OUTPUT     = 4'd8;   // output vocab projection (243→729)
    localparam S_ARGMAX     = 4'd9;   // find max logit
    localparam S_DONE       = 4'd10;

    reg [3:0] state;
    reg [1:0] block_idx;  // current transformer block (0..2)

    // Activation buffers (double-buffered for pipeline)
    reg signed [INPUT_WIDTH-1:0] activation [0:HIDDEN_DIM-1];
    reg signed [ACC_WIDTH-1:0]   layer_out  [0:HIDDEN_DIM-1];

    // Weight address offset per layer
    reg [15:0] weight_base;

    // Layer controller interface
    reg  layer_start;
    wire layer_done;

    // Debug output
    assign debug_byte  = state;
    assign debug_valid = (state != S_IDLE);
    assign weight_addr = weight_base + layer_start;  // simplified

    // ═══ STATE MACHINE ═══
    always @(posedge clk) begin
        if (rst) begin
            state        <= S_IDLE;
            block_idx    <= 0;
            done         <= 0;
            busy         <= 0;
            layer_start  <= 0;
            output_token <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= S_EMBED;
                        busy  <= 1;
                        block_idx <= 0;
                    end
                end

                S_EMBED: begin
                    // Token → embedding lookup (BRAM read, 1 cycle)
                    // In practice: read EMBED_DIM values from weight BRAM
                    // at offset token_id × EMBED_DIM
                    state <= S_ATTN_QKV;
                    layer_start <= 1;
                end

                S_ATTN_QKV: begin
                    layer_start <= 0;
                    if (layer_done) begin
                        state <= S_ATTN_OUT;  // simplified: skip score/apply
                    end
                end

                S_ATTN_OUT: begin
                    if (layer_done)
                        state <= S_FFN_UP;
                end

                S_FFN_UP: begin
                    if (layer_done)
                        state <= S_FFN_DOWN;
                end

                S_FFN_DOWN: begin
                    if (layer_done) begin
                        if (block_idx == N_BLOCKS - 1) begin
                            state <= S_OUTPUT;
                        end else begin
                            block_idx <= block_idx + 1;
                            state     <= S_ATTN_QKV;
                        end
                    end
                end

                S_OUTPUT: begin
                    if (layer_done)
                        state <= S_ARGMAX;
                end

                S_ARGMAX: begin
                    // Find max of 729 logits
                    // Simplified: takes ~729 cycles
                    state <= S_DONE;
                end

                S_DONE: begin
                    done <= 1;
                    busy <= 0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // Placeholder for layer_done (connected to actual layer controller)
    assign layer_done = 0; // TODO: wire to layer_controller instance

endmodule
