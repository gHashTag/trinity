//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// TMU — Ternary MatMul Unit (K-Parallel Dot Product, Wide BRAM)
// =============================================================================
// Computes y[j] = sum_i W[i][j] * x[i]  where W[i][j] in {-1, 0, +1}
//
// Architecture: K weights processed per cycle via SINGLE wide BRAM + adder tree
//   - x_buffer filled during S_FILL phase (N_IN cycles)
//   - S_PREFETCH loads K values from x_buffer BRAM into x_reg[] one-at-a-time
//   - S_COMPUTE: K x_reg values + K weight codes from wide BRAM → adder tree
//   - Accumulator sums tree output across ceil(N_IN/K) steps
//
// DRAM-free design: x_buffer marked ram_style=block (single read port).
//   K parallel reads replaced by K-cycle prefetch into x_reg[0:K-1] registers.
//   x_reg is K flip-flops — never inferred as distributed RAM.
//
// Wide BRAM (weight): packs K banks into one (2*K)-bit-wide memory.
//   K=32: 64-bit wide → 1 BRAM36 read port per TMU instance
//   K=16: 32-bit wide → 1 BRAM18 read port per TMU instance
//
// Cycle budget (K=16, N_IN=243, N_OUT=729, STEPS_PER_OUT=16):
//   S_FILL:     243 cycles
//   Per output: K_prefetch (K+1=17) + STEPS_PER_OUT compute = 33 cycles/step × 16 steps = 528
//   Total:      729 × 528 ≈ 385K cycles/token  (vs 81K zero-bubble; 4.75× slower, synthesises)
//
// Weight encoding: 2'b01=+1, 2'b10=-1, 2'b00=0
// Wide word layout: {w[K-1], ..., w[1], w[0]} where each w[b] is 2 bits
// Address: j * STEPS_PER_OUT + (i / K)
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module tmu #(
    parameter N_IN            = 243,
    parameter N_OUT           = 729,
    parameter K               = 32,
    parameter ACC_WIDTH       = 20,
    parameter ADDR_WIDTH      = 18,
    parameter I_WIDTH         = 8,
    parameter J_WIDTH         = 10,
    parameter MEM_FILE_PREFIX = "tmu_w",
    parameter USE_EXT_X       = 0
)(
    input  wire                        clk,
    input  wire                        rst,
    input  wire                        start,
    output reg  signed [ACC_WIDTH-1:0] result_data,
    output reg  [J_WIDTH-1:0]          result_addr,
    output reg                         result_valid,
    output reg                         done,
    output reg                         busy,
    input  wire signed [ACC_WIDTH-1:0] x_ext_data,
    output wire [I_WIDTH-1:0]          x_ext_addr
);

    // K guard — only K=16 and K=32 supported
    initial begin
        if (K != 16 && K != 32) begin
            $display("ERROR: TMU requires K=16 or K=32, got K=%0d", K);
            $finish;
        end
    end

    // =========================================================================
    // DERIVED PARAMETERS
    // =========================================================================
    localparam STEPS_PER_OUT = (N_IN + K - 1) / K;  // ceil(N_IN / K)
    localparam BANK_DEPTH    = STEPS_PER_OUT * N_OUT;

    function integer clog2(input integer val);
        integer i;
        begin
            clog2 = 0;
            for (i = val - 1; i > 0; i = i >> 1)
                clog2 = clog2 + 1;
        end
    endfunction

    localparam BANK_ADDR_BITS = clog2(BANK_DEPTH > 0 ? BANK_DEPTH : 1);
    localparam BANK_MEM_DEPTH = 1 << BANK_ADDR_BITS;
    localparam WIDE_BITS      = 2 * K;  // 64 for K=32, 32 for K=16

    // Width for prefetch counter (0..K-1 + 1 for BRAM latency)
    localparam K_WIDTH        = (K == 32) ? 6 : 5;  // enough bits for 0..K

    // Width-safe comparison constants
    localparam [I_WIDTH-1:0] LAST_I = N_IN - 1;
    localparam [J_WIDTH-1:0] LAST_J = N_OUT - 1;

    // =========================================================================
    // X BUFFER — BRAM (single read port, registered output)
    // =========================================================================
    // Marked ram_style=block so Yosys infers Block RAM, not distributed RAM.
    // Only one read address issued per cycle → no multi-port DRAM inference.

    (* ram_style = "block" *)
    reg signed [ACC_WIDTH-1:0] x_buffer [0:N_IN-1];

    reg [I_WIDTH-1:0] fill_idx;
    assign x_ext_addr = fill_idx;

    wire signed [ACC_WIDTH-1:0] x_fill_val;
    generate
        if (USE_EXT_X) begin : gen_ext_x
            assign x_fill_val = x_ext_data;
        end else begin : gen_self_x
            assign x_fill_val = {{(ACC_WIDTH - I_WIDTH - 1){1'b0}}, fill_idx} + {{(ACC_WIDTH-1){1'b0}}, 1'b1};
        end
    endgenerate

    // Single-port BRAM read — address driven by FSM, 1-cycle read latency
    reg [I_WIDTH-1:0]          xbuf_rd_addr;
    reg signed [ACC_WIDTH-1:0] xbuf_rd_data;  // registered output (latency=1)

    always @(posedge clk) begin
        xbuf_rd_data <= x_buffer[xbuf_rd_addr];
    end

    // =========================================================================
    // X REGISTER FILE — K flip-flops loaded during S_PREFETCH
    // =========================================================================
    // K=16 or K=32 plain registers — synthesiser will NOT infer RAM for these
    // because they are only written sequentially (one per cycle) and read all
    // at once combinationally in S_COMPUTE.
    // Yosys DRAM inference requires write-enable on individual elements
    // selected by a runtime index; here each element has a fixed address
    // decoded from pf_cnt via the generate loop.

    reg signed [ACC_WIDTH-1:0] x_reg [0:K-1];

    // =========================================================================
    // WIDE BRAM — single (2*K)-bit-wide memory replaces K separate 2-bit banks
    // =========================================================================
    // One read per cycle → K weight codes extracted combinationally.
    // (* ram_style = "block" *) forces Block RAM inference in Yosys/Vivado.

    (* ram_style = "block" *)
    reg [WIDE_BITS-1:0] bank_mem_wide [0:BANK_MEM_DEPTH-1];

    initial $readmemb({MEM_FILE_PREFIX, "_wide.mem"}, bank_mem_wide);

    reg [BANK_ADDR_BITS-1:0] bank_rd_addr;
    reg [WIDE_BITS-1:0]      bank_word;

    // Registered BRAM read (1-cycle latency)
    always @(posedge clk) begin
        bank_word <= bank_mem_wide[bank_rd_addr];
    end

    // Combinational extraction: split wide word into K 2-bit codes
    wire [1:0] w_code [0:K-1];
    genvar b;
    generate
        for (b = 0; b < K; b = b + 1) begin : gen_wcode
            assign w_code[b] = bank_word[2*b +: 2];
        end
    endgenerate

    // =========================================================================
    // TERNARY MUX — K partial products using x_reg (DRAM-free)
    // =========================================================================
    // x_reg[b] is a simple register index — no runtime-indexed array read.
    // The (x_idx < N_IN) guard handles the tail partial step where
    // step_base + b >= N_IN; those x_reg entries are zero-initialised and
    // loaded with 0 during S_PREFETCH for out-of-range indices.

    wire signed [ACC_WIDTH-1:0] partial [0:K-1];

    generate
        for (b = 0; b < K; b = b + 1) begin : gen_partial
            assign partial[b] = (w_code[b] == 2'b01) ?  x_reg[b] :
                                (w_code[b] == 2'b10) ? -x_reg[b] :
                                                        {ACC_WIDTH{1'b0}};
        end
    endgenerate

    // =========================================================================
    // ADDER TREE — K=16: 4 stages, K=32: 5 stages (combinational)
    // =========================================================================
    wire signed [ACC_WIDTH-1:0] tree_sum;

    generate if (K == 16) begin : gen_tree_k16
        wire signed [ACC_WIDTH-1:0] s1 [0:7];
        wire signed [ACC_WIDTH-1:0] s2 [0:3];
        wire signed [ACC_WIDTH-1:0] s3 [0:1];

        for (b = 0; b < 8; b = b + 1) begin : gs1
            assign s1[b] = partial[2*b] + partial[2*b+1];
        end
        for (b = 0; b < 4; b = b + 1) begin : gs2
            assign s2[b] = s1[2*b] + s1[2*b+1];
        end
        for (b = 0; b < 2; b = b + 1) begin : gs3
            assign s3[b] = s2[2*b] + s2[2*b+1];
        end
        assign tree_sum = s3[0] + s3[1];

    end else begin : gen_tree_k32
        wire signed [ACC_WIDTH-1:0] s1 [0:15];
        wire signed [ACC_WIDTH-1:0] s2 [0:7];
        wire signed [ACC_WIDTH-1:0] s3 [0:3];
        wire signed [ACC_WIDTH-1:0] s4 [0:1];

        for (b = 0; b < 16; b = b + 1) begin : gs1
            assign s1[b] = partial[2*b] + partial[2*b+1];
        end
        for (b = 0; b < 8; b = b + 1) begin : gs2
            assign s2[b] = s1[2*b] + s1[2*b+1];
        end
        for (b = 0; b < 4; b = b + 1) begin : gs3
            assign s3[b] = s2[2*b] + s2[2*b+1];
        end
        for (b = 0; b < 2; b = b + 1) begin : gs4
            assign s4[b] = s3[2*b] + s3[2*b+1];
        end
        assign tree_sum = s4[0] + s4[1];

    end endgenerate

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    // S_IDLE    → S_FILL     (on start)
    // S_FILL    → S_PREFETCH (after N_IN cycles)
    // S_PREFETCH→ S_COMPUTE  (after K+1 cycles: K addr issues + 1 BRAM latency)
    // S_COMPUTE → S_PREFETCH (if more steps remain for this j)
    //           → S_OUTPUT   (last step for this j)
    // S_OUTPUT  → S_PREFETCH (next j, if j < LAST_J)
    //           → S_DONE     (if j == LAST_J)
    // S_DONE    → S_IDLE
    //
    // S_PREFETCH details:
    //   pf_cnt=0:     issue xbuf_rd_addr = step_base + 0
    //   pf_cnt=1:     x_reg[0] <= xbuf_rd_data; issue addr for x_reg[1]
    //   ...
    //   pf_cnt=K-1:   x_reg[K-2] loaded; issue addr for x_reg[K-1]
    //   pf_cnt=K:     x_reg[K-1] loaded; issue bank_rd_addr; → S_COMPUTE
    //                 (bank_word valid on first cycle of S_COMPUTE)
    //
    // S_COMPUTE details (1 cycle):
    //   acc += tree_sum  (bank_word and x_reg[] both valid)
    //   If last step → S_OUTPUT, else advance step and → S_PREFETCH

    localparam S_IDLE      = 3'd0;
    localparam S_FILL      = 3'd1;
    localparam S_PREFETCH  = 3'd2;
    localparam S_COMPUTE   = 3'd3;
    localparam S_OUTPUT    = 3'd4;
    localparam S_DONE      = 3'd5;

    reg [2:0] state;
    reg signed [ACC_WIDTH-1:0] acc;
    reg [J_WIDTH-1:0]          j_idx;
    reg [BANK_ADDR_BITS-1:0]   step_cnt;       // which K-group within current j
    reg [BANK_ADDR_BITS-1:0]   j_base_addr;    // j * STEPS_PER_OUT
    reg [I_WIDTH-1:0]          step_base;      // step_cnt * K (x index of first element)
    reg [K_WIDTH-1:0]          pf_cnt;         // prefetch counter 0..K

    localparam [BANK_ADDR_BITS-1:0] STEPS_M1 = STEPS_PER_OUT - 1;

    // Prefetch address computation — module-scope wire, no inline reg declarations.
    // Computes step_base + pf_cnt with one extra bit to detect out-of-range.
    wire [I_WIDTH:0] pf_xidx_wide;
    assign pf_xidx_wide = {1'b0, step_base} + {{(I_WIDTH-K_WIDTH+1){1'b0}}, pf_cnt};

    // Generate loop for x_reg write — each register pb gets written when
    // pf_cnt == pb+1 (one cycle after addr pb was issued, BRAM latency=1).
    // Using individual equality comparisons avoids a runtime-indexed LHS,
    // which is what triggers distributed-RAM inference in Yosys.
    genvar pb;
    generate
        for (pb = 0; pb < K; pb = pb + 1) begin : gen_xreg_load
            always @(posedge clk) begin
                if (rst) begin
                    x_reg[pb] <= {ACC_WIDTH{1'b0}};
                end else if (state == S_PREFETCH && pf_cnt == (pb[K_WIDTH-1:0] + {{(K_WIDTH-1){1'b0}},1'b1})) begin
                    // xbuf_rd_data is the result of the address issued when pf_cnt==pb
                    x_reg[pb] <= xbuf_rd_data;
                end
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            state         <= S_IDLE;
            fill_idx      <= {I_WIDTH{1'b0}};
            j_idx         <= {J_WIDTH{1'b0}};
            step_cnt      <= {BANK_ADDR_BITS{1'b0}};
            j_base_addr   <= {BANK_ADDR_BITS{1'b0}};
            step_base     <= {I_WIDTH{1'b0}};
            pf_cnt        <= {K_WIDTH{1'b0}};
            xbuf_rd_addr  <= {I_WIDTH{1'b0}};
            bank_rd_addr  <= {BANK_ADDR_BITS{1'b0}};
            acc           <= {ACC_WIDTH{1'b0}};
            done          <= 1'b0;
            busy          <= 1'b0;
            result_valid  <= 1'b0;
            result_data   <= {ACC_WIDTH{1'b0}};
            result_addr   <= {J_WIDTH{1'b0}};
        end else begin
            done         <= 1'b0;
            result_valid <= 1'b0;

            case (state)
                // ---------------------------------------------------------
                S_IDLE: begin
                    if (start) begin
                        fill_idx <= {I_WIDTH{1'b0}};
                        busy     <= 1'b1;
                        state    <= S_FILL;
                    end
                end

                // ---------------------------------------------------------
                // S_FILL: write N_IN values into x_buffer BRAM one per cycle
                S_FILL: begin
                    x_buffer[fill_idx] <= x_fill_val;
                    if (fill_idx == LAST_I) begin
                        j_idx        <= {J_WIDTH{1'b0}};
                        j_base_addr  <= {BANK_ADDR_BITS{1'b0}};
                        step_cnt     <= {BANK_ADDR_BITS{1'b0}};
                        step_base    <= {I_WIDTH{1'b0}};
                        acc          <= {ACC_WIDTH{1'b0}};
                        pf_cnt       <= {K_WIDTH{1'b0}};
                        xbuf_rd_addr <= {I_WIDTH{1'b0}};
                        state        <= S_PREFETCH;
                    end else begin
                        fill_idx <= fill_idx + {{(I_WIDTH-1){1'b0}}, 1'b1};
                    end
                end

                // ---------------------------------------------------------
                // S_PREFETCH: load K values from x_buffer BRAM into x_reg[]
                //
                // On cycles pf_cnt = 0..K-1:
                //   Issue xbuf_rd_addr = step_base + pf_cnt (clamped to 0 if OOB)
                //   gen_xreg_load flops capture xbuf_rd_data one cycle later
                //
                // On cycle pf_cnt = K:
                //   All K x_reg entries are valid
                //   Issue bank_rd_addr = j_base_addr + step_cnt
                //   Transition to S_COMPUTE (bank_word valid next cycle)
                S_PREFETCH: begin
                    if (pf_cnt < K[K_WIDTH-1:0]) begin
                        // Issue x_buffer read address (clamped if out-of-range)
                        xbuf_rd_addr <= (pf_xidx_wide < N_IN[I_WIDTH:0])
                                        ? pf_xidx_wide[I_WIDTH-1:0]
                                        : {I_WIDTH{1'b0}};
                        pf_cnt <= pf_cnt + {{(K_WIDTH-1){1'b0}}, 1'b1};
                    end else begin
                        // All K x_reg values loaded; arm weight BRAM read
                        bank_rd_addr <= j_base_addr + step_cnt;
                        pf_cnt       <= {K_WIDTH{1'b0}};
                        state        <= S_COMPUTE;
                    end
                end

                // ---------------------------------------------------------
                // S_COMPUTE: one cycle
                //   bank_word valid (issued on last pf_cnt==K cycle, latency=1)
                //   x_reg[] valid (loaded during S_PREFETCH)
                //   acc accumulates tree_sum
                S_COMPUTE: begin
                    acc <= acc + tree_sum;

                    if (step_cnt == STEPS_M1) begin
                        state <= S_OUTPUT;
                    end else begin
                        step_cnt     <= step_cnt + {{(BANK_ADDR_BITS-1){1'b0}}, 1'b1};
                        step_base    <= step_base + K[I_WIDTH-1:0];
                        pf_cnt       <= {K_WIDTH{1'b0}};
                        // Prime the first xbuf read of the next prefetch
                        xbuf_rd_addr <= step_base + K[I_WIDTH-1:0];
                        state        <= S_PREFETCH;
                    end
                end

                // ---------------------------------------------------------
                // S_OUTPUT: emit accumulated result for j_idx
                // acc holds the final dot product (updated in last S_COMPUTE)
                S_OUTPUT: begin
                    result_data  <= acc;
                    result_addr  <= j_idx;
                    result_valid <= 1'b1;

                    if (j_idx == LAST_J) begin
                        state <= S_DONE;
                    end else begin
                        j_idx        <= j_idx + {{(J_WIDTH-1){1'b0}}, 1'b1};
                        j_base_addr  <= j_base_addr + STEPS_PER_OUT[BANK_ADDR_BITS-1:0];
                        step_cnt     <= {BANK_ADDR_BITS{1'b0}};
                        step_base    <= {I_WIDTH{1'b0}};
                        acc          <= {ACC_WIDTH{1'b0}};
                        pf_cnt       <= {K_WIDTH{1'b0}};
                        xbuf_rd_addr <= {I_WIDTH{1'b0}};
                        state        <= S_PREFETCH;
                    end
                end

                // ---------------------------------------------------------
                S_DONE: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule
