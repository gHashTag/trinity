// =============================================================================
// TMU — Ternary MatMul Unit (K-Parallel Dot Product, Wide BRAM)
// =============================================================================
// Computes y[j] = sum_i W[i][j] * x[i]  where W[i][j] in {-1, 0, +1}
//
// Architecture: K weights processed per cycle via SINGLE wide BRAM + adder tree
//   - x_buffer filled during S_FILL phase (N_IN cycles)
//   - One wide BRAM read: (2*K)-bit word → K 2-bit weight codes
//   - Combinational adder tree reduces K partial products
//   - Accumulator sums tree output across ceil(N_IN/K) steps
//
// Wide BRAM: packs K banks into one (2*K)-bit-wide memory.
//   K=32: 64-bit wide → 1 BRAM36 read port per TMU instance
//   K=16: 32-bit wide → 1 BRAM18 read port per TMU instance
//   Eliminates distributed-RAM LUT explosion from narrow 2-bit banks.
//
// K=32: 243x729 matvec in ~6.8K cycles (zero-bubble FSM)
// K=16: 243x729 matvec in ~12.4K cycles
//
// Weight encoding: 2'b01=+1, 2'b10=-1, 2'b00=0
// Wide word layout: {w[K-1], ..., w[1], w[0]} where each w[b] is 2 bits
// Address: j * STEPS_PER_OUT + (i / K), bank index = i % K
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

    // Width-safe comparison constants
    localparam [I_WIDTH-1:0] LAST_I = N_IN - 1;
    localparam [J_WIDTH-1:0] LAST_J = N_OUT - 1;

    // =========================================================================
    // X BUFFER — filled during S_FILL, read K values/cycle during S_COMPUTE
    // =========================================================================
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
    // TERNARY MUX — K partial products (combinational)
    // =========================================================================
    reg [I_WIDTH-1:0] step_base_d1;

    wire signed [ACC_WIDTH-1:0] partial [0:K-1];
    wire signed [ACC_WIDTH-1:0] x_buf_val [0:K-1];

    generate
        for (b = 0; b < K; b = b + 1) begin : gen_partial
            wire [I_WIDTH:0] x_idx = {1'b0, step_base_d1} + b[I_WIDTH:0];
            assign x_buf_val[b] = (x_idx < N_IN) ? x_buffer[x_idx[I_WIDTH-1:0]] : {ACC_WIDTH{1'b0}};

            assign partial[b] = (w_code[b] == 2'b01) ?  x_buf_val[b] :
                                (w_code[b] == 2'b10) ? -x_buf_val[b] :
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
    // STATE MACHINE — Zero-bubble: PREFETCH merged into FILL/OUTPUT
    // =========================================================================
    localparam S_IDLE    = 3'd0;
    localparam S_FILL    = 3'd1;
    localparam S_COMPUTE = 3'd2;
    localparam S_OUTPUT  = 3'd3;
    localparam S_DONE    = 3'd4;

    reg [2:0] state;
    reg signed [ACC_WIDTH-1:0] acc;
    reg [J_WIDTH-1:0]   j_idx;
    reg [BANK_ADDR_BITS-1:0] step_cnt;
    reg [BANK_ADDR_BITS-1:0] j_base_addr;
    reg [I_WIDTH-1:0] step_base;
    reg                compute_valid;

    localparam [BANK_ADDR_BITS-1:0] STEPS_M1 = STEPS_PER_OUT - 1;

    always @(posedge clk) begin
        if (rst) begin
            state         <= S_IDLE;
            fill_idx      <= {I_WIDTH{1'b0}};
            j_idx         <= {J_WIDTH{1'b0}};
            step_cnt      <= {BANK_ADDR_BITS{1'b0}};
            j_base_addr   <= {BANK_ADDR_BITS{1'b0}};
            step_base     <= {I_WIDTH{1'b0}};
            step_base_d1  <= {I_WIDTH{1'b0}};
            bank_rd_addr  <= {BANK_ADDR_BITS{1'b0}};
            acc           <= {ACC_WIDTH{1'b0}};
            done          <= 1'b0;
            busy          <= 1'b0;
            result_valid  <= 1'b0;
            result_data   <= {ACC_WIDTH{1'b0}};
            result_addr   <= {J_WIDTH{1'b0}};
            compute_valid <= 1'b0;
        end else begin
            done          <= 1'b0;
            result_valid  <= 1'b0;
            compute_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        fill_idx <= {I_WIDTH{1'b0}};
                        busy     <= 1'b1;
                        state    <= S_FILL;
                    end
                end

                S_FILL: begin
                    x_buffer[fill_idx] <= x_fill_val;
                    if (fill_idx == LAST_I) begin
                        j_idx        <= {J_WIDTH{1'b0}};
                        j_base_addr  <= {BANK_ADDR_BITS{1'b0}};
                        step_cnt     <= {BANK_ADDR_BITS{1'b0}};
                        step_base    <= {I_WIDTH{1'b0}};
                        bank_rd_addr <= {BANK_ADDR_BITS{1'b0}};
                        acc          <= {ACC_WIDTH{1'b0}};
                        state        <= S_COMPUTE;
                    end else begin
                        fill_idx <= fill_idx + {{(I_WIDTH-1){1'b0}}, 1'b1};
                    end
                end

                S_COMPUTE: begin
                    step_base_d1 <= step_base;

                    if (compute_valid)
                        acc <= acc + tree_sum;

                    if (step_cnt == STEPS_M1) begin
                        compute_valid <= 1'b1;
                        state         <= S_OUTPUT;
                    end else begin
                        compute_valid <= 1'b1;
                        step_cnt     <= step_cnt + {{(BANK_ADDR_BITS-1){1'b0}}, 1'b1};
                        step_base    <= step_base + K[I_WIDTH-1:0];
                        bank_rd_addr <= j_base_addr + step_cnt + {{(BANK_ADDR_BITS-1){1'b0}}, 1'b1};
                    end
                end

                S_OUTPUT: begin
                    result_data  <= acc + tree_sum;
                    result_addr  <= j_idx;
                    result_valid <= 1'b1;

                    if (j_idx == LAST_J) begin
                        state <= S_DONE;
                    end else begin
                        j_idx        <= j_idx + {{(J_WIDTH-1){1'b0}}, 1'b1};
                        j_base_addr  <= j_base_addr + STEPS_PER_OUT[BANK_ADDR_BITS-1:0];
                        bank_rd_addr <= j_base_addr + STEPS_PER_OUT[BANK_ADDR_BITS-1:0];
                        step_cnt     <= {BANK_ADDR_BITS{1'b0}};
                        step_base    <= {I_WIDTH{1'b0}};
                        acc          <= {ACC_WIDTH{1'b0}};
                        state        <= S_COMPUTE;
                    end
                end

                S_DONE: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
