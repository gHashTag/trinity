// =============================================================================
// TMU — Ternary MatMul Unit (K-Parallel Dot Product)
// =============================================================================
// Computes y[j] = sum_i W[i][j] * x[i]  where W[i][j] in {-1, 0, +1}
//
// Architecture: K weights processed per cycle via banked BRAMs + adder tree
//   - x_buffer filled during S_FILL phase (N_IN cycles)
//   - K BRAM banks read K weights simultaneously
//   - 5-stage combinational adder tree reduces K partial products
//   - Accumulator sums tree output across ceil(N_IN/K) steps
//
// Default K=32: 243x729 matvec in ~6.8K cycles (zero-bubble FSM)
// vs K=16: ~12.4K cycles → 1.82x speedup
// vs K=1 baseline: 178K cycles → 26.2x speedup
//
// Weight encoding: 2'b01=+1, 2'b10=-1, 2'b00=0
// Bank layout: bank b = i % K, addr = j * ceil(N_IN/K) + (i / K)
//
// Drop-in replacement for ternary_matvec_bram (same port interface).
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

    // K=32 guard — internal structure is hardcoded for 32 banks + 5-stage adder tree
    initial begin
        if (K != 32) begin
            $display("ERROR: TMU requires K=32, got K=%0d", K);
            $finish;
        end
    end

    // =========================================================================
    // DERIVED PARAMETERS
    // =========================================================================
    localparam STEPS_PER_OUT = (N_IN + K - 1) / K;  // ceil(N_IN / K)
    localparam BANK_DEPTH    = STEPS_PER_OUT * N_OUT;

    // Pad bank depth to power of 2 for clean BRAM inference
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

    // Width-safe comparison constants
    localparam [I_WIDTH-1:0] LAST_I = N_IN - 1;
    localparam [J_WIDTH-1:0] LAST_J = N_OUT - 1;

    // =========================================================================
    // X BUFFER — filled during S_FILL, read K values/cycle during S_COMPUTE
    // =========================================================================
    reg signed [ACC_WIDTH-1:0] x_buffer [0:N_IN-1];
    reg [I_WIDTH-1:0] fill_idx;

    assign x_ext_addr = fill_idx;

    // Input value for fill: self-test (i+1) or external
    wire signed [ACC_WIDTH-1:0] x_fill_val;
    generate
        if (USE_EXT_X) begin : gen_ext_x
            assign x_fill_val = x_ext_data;
        end else begin : gen_self_x
            assign x_fill_val = {{(ACC_WIDTH - I_WIDTH - 1){1'b0}}, fill_idx} + {{(ACC_WIDTH-1){1'b0}}, 1'b1};
        end
    endgenerate

    // =========================================================================
    // WEIGHT BRAM BANKS — 32 banks, each BANK_MEM_DEPTH x 2-bit
    // =========================================================================
    // Bank b stores weights where (i % K) == b
    // Address in bank: j * STEPS_PER_OUT + (i / K)

    reg [1:0] bank_mem_0  [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_1  [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_2  [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_3  [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_4  [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_5  [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_6  [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_7  [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_8  [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_9  [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_10 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_11 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_12 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_13 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_14 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_15 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_16 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_17 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_18 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_19 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_20 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_21 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_22 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_23 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_24 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_25 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_26 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_27 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_28 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_29 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_30 [0:BANK_MEM_DEPTH-1];
    reg [1:0] bank_mem_31 [0:BANK_MEM_DEPTH-1];

    initial begin
        $readmemb({MEM_FILE_PREFIX, "_b00.mem"}, bank_mem_0);
        $readmemb({MEM_FILE_PREFIX, "_b01.mem"}, bank_mem_1);
        $readmemb({MEM_FILE_PREFIX, "_b02.mem"}, bank_mem_2);
        $readmemb({MEM_FILE_PREFIX, "_b03.mem"}, bank_mem_3);
        $readmemb({MEM_FILE_PREFIX, "_b04.mem"}, bank_mem_4);
        $readmemb({MEM_FILE_PREFIX, "_b05.mem"}, bank_mem_5);
        $readmemb({MEM_FILE_PREFIX, "_b06.mem"}, bank_mem_6);
        $readmemb({MEM_FILE_PREFIX, "_b07.mem"}, bank_mem_7);
        $readmemb({MEM_FILE_PREFIX, "_b08.mem"}, bank_mem_8);
        $readmemb({MEM_FILE_PREFIX, "_b09.mem"}, bank_mem_9);
        $readmemb({MEM_FILE_PREFIX, "_b10.mem"}, bank_mem_10);
        $readmemb({MEM_FILE_PREFIX, "_b11.mem"}, bank_mem_11);
        $readmemb({MEM_FILE_PREFIX, "_b12.mem"}, bank_mem_12);
        $readmemb({MEM_FILE_PREFIX, "_b13.mem"}, bank_mem_13);
        $readmemb({MEM_FILE_PREFIX, "_b14.mem"}, bank_mem_14);
        $readmemb({MEM_FILE_PREFIX, "_b15.mem"}, bank_mem_15);
        $readmemb({MEM_FILE_PREFIX, "_b16.mem"}, bank_mem_16);
        $readmemb({MEM_FILE_PREFIX, "_b17.mem"}, bank_mem_17);
        $readmemb({MEM_FILE_PREFIX, "_b18.mem"}, bank_mem_18);
        $readmemb({MEM_FILE_PREFIX, "_b19.mem"}, bank_mem_19);
        $readmemb({MEM_FILE_PREFIX, "_b20.mem"}, bank_mem_20);
        $readmemb({MEM_FILE_PREFIX, "_b21.mem"}, bank_mem_21);
        $readmemb({MEM_FILE_PREFIX, "_b22.mem"}, bank_mem_22);
        $readmemb({MEM_FILE_PREFIX, "_b23.mem"}, bank_mem_23);
        $readmemb({MEM_FILE_PREFIX, "_b24.mem"}, bank_mem_24);
        $readmemb({MEM_FILE_PREFIX, "_b25.mem"}, bank_mem_25);
        $readmemb({MEM_FILE_PREFIX, "_b26.mem"}, bank_mem_26);
        $readmemb({MEM_FILE_PREFIX, "_b27.mem"}, bank_mem_27);
        $readmemb({MEM_FILE_PREFIX, "_b28.mem"}, bank_mem_28);
        $readmemb({MEM_FILE_PREFIX, "_b29.mem"}, bank_mem_29);
        $readmemb({MEM_FILE_PREFIX, "_b30.mem"}, bank_mem_30);
        $readmemb({MEM_FILE_PREFIX, "_b31.mem"}, bank_mem_31);
    end

    // Registered BRAM reads (1-cycle latency)
    reg [BANK_ADDR_BITS-1:0] bank_rd_addr;
    reg [1:0] w_code [0:K-1];

    always @(posedge clk) begin
        w_code[0]  <= bank_mem_0 [bank_rd_addr];
        w_code[1]  <= bank_mem_1 [bank_rd_addr];
        w_code[2]  <= bank_mem_2 [bank_rd_addr];
        w_code[3]  <= bank_mem_3 [bank_rd_addr];
        w_code[4]  <= bank_mem_4 [bank_rd_addr];
        w_code[5]  <= bank_mem_5 [bank_rd_addr];
        w_code[6]  <= bank_mem_6 [bank_rd_addr];
        w_code[7]  <= bank_mem_7 [bank_rd_addr];
        w_code[8]  <= bank_mem_8 [bank_rd_addr];
        w_code[9]  <= bank_mem_9 [bank_rd_addr];
        w_code[10] <= bank_mem_10[bank_rd_addr];
        w_code[11] <= bank_mem_11[bank_rd_addr];
        w_code[12] <= bank_mem_12[bank_rd_addr];
        w_code[13] <= bank_mem_13[bank_rd_addr];
        w_code[14] <= bank_mem_14[bank_rd_addr];
        w_code[15] <= bank_mem_15[bank_rd_addr];
        w_code[16] <= bank_mem_16[bank_rd_addr];
        w_code[17] <= bank_mem_17[bank_rd_addr];
        w_code[18] <= bank_mem_18[bank_rd_addr];
        w_code[19] <= bank_mem_19[bank_rd_addr];
        w_code[20] <= bank_mem_20[bank_rd_addr];
        w_code[21] <= bank_mem_21[bank_rd_addr];
        w_code[22] <= bank_mem_22[bank_rd_addr];
        w_code[23] <= bank_mem_23[bank_rd_addr];
        w_code[24] <= bank_mem_24[bank_rd_addr];
        w_code[25] <= bank_mem_25[bank_rd_addr];
        w_code[26] <= bank_mem_26[bank_rd_addr];
        w_code[27] <= bank_mem_27[bank_rd_addr];
        w_code[28] <= bank_mem_28[bank_rd_addr];
        w_code[29] <= bank_mem_29[bank_rd_addr];
        w_code[30] <= bank_mem_30[bank_rd_addr];
        w_code[31] <= bank_mem_31[bank_rd_addr];
    end

    // =========================================================================
    // TERNARY MUX — K partial products (combinational)
    // =========================================================================
    // w_code[b] selects: 01→+x, 10→-x, 00→0
    // x index for bank b at step s: s*K + b (clamped to 0 if out of range)

    reg [I_WIDTH-1:0] step_base_d1;  // delayed by 1 cycle to align with BRAM output

    wire signed [ACC_WIDTH-1:0] partial [0:K-1];

    // Read K values from x_buffer, guard against out-of-range
    wire signed [ACC_WIDTH-1:0] x_buf_val [0:K-1];

    genvar b;
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
    // ADDER TREE — 5 stages, combinational (32 → 1)
    // =========================================================================
    wire signed [ACC_WIDTH-1:0] s1 [0:15]; // 32 → 16
    wire signed [ACC_WIDTH-1:0] s2 [0:7];  // 16 → 8
    wire signed [ACC_WIDTH-1:0] s3 [0:3];  // 8 → 4
    wire signed [ACC_WIDTH-1:0] s4 [0:1];  // 4 → 2
    wire signed [ACC_WIDTH-1:0] tree_sum;  // 2 → 1

    generate
        for (b = 0; b < 16; b = b + 1) begin : gen_s1
            assign s1[b] = partial[2*b] + partial[2*b+1];
        end
        for (b = 0; b < 8; b = b + 1) begin : gen_s2
            assign s2[b] = s1[2*b] + s1[2*b+1];
        end
        for (b = 0; b < 4; b = b + 1) begin : gen_s3
            assign s3[b] = s2[2*b] + s2[2*b+1];
        end
        for (b = 0; b < 2; b = b + 1) begin : gen_s4
            assign s4[b] = s3[2*b] + s3[2*b+1];
        end
    endgenerate

    assign tree_sum = s4[0] + s4[1];

    // =========================================================================
    // STATE MACHINE — Zero-bubble: PREFETCH merged into FILL/OUTPUT
    // =========================================================================
    // Old: FILL → PREFETCH → COMPUTE → OUTPUT → PREFETCH → ... (STEPS+2 per j)
    // New: FILL → COMPUTE → OUTPUT → COMPUTE → ...          (STEPS+1 per j)
    // Saves 1 cycle per output j by launching BRAM read in FILL/OUTPUT.
    localparam S_IDLE    = 3'd0;
    localparam S_FILL    = 3'd1;
    localparam S_COMPUTE = 3'd2;
    localparam S_OUTPUT  = 3'd3;
    localparam S_DONE    = 3'd4;

    reg [2:0] state;
    reg signed [ACC_WIDTH-1:0] acc;
    reg [J_WIDTH-1:0]   j_idx;
    reg [BANK_ADDR_BITS-1:0] step_cnt;       // current step within one output
    reg [BANK_ADDR_BITS-1:0] j_base_addr;    // j * STEPS_PER_OUT
    reg [I_WIDTH-1:0] step_base;              // step_cnt * K (x_buffer base index)
    reg                compute_valid;          // delayed flag: BRAM data is ready

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
                // ---------------------------------------------------------
                // IDLE: Wait for start
                // ---------------------------------------------------------
                S_IDLE: begin
                    if (start) begin
                        fill_idx <= {I_WIDTH{1'b0}};
                        busy     <= 1'b1;
                        state    <= S_FILL;
                    end
                end

                // ---------------------------------------------------------
                // FILL: Load x_buffer, launch first BRAM read on last cycle
                // ---------------------------------------------------------
                S_FILL: begin
                    x_buffer[fill_idx] <= x_fill_val;
                    if (fill_idx == LAST_I) begin
                        // Done filling — launch first BRAM read (replaces PREFETCH)
                        j_idx        <= {J_WIDTH{1'b0}};
                        j_base_addr  <= {BANK_ADDR_BITS{1'b0}};
                        step_cnt     <= {BANK_ADDR_BITS{1'b0}};
                        step_base    <= {I_WIDTH{1'b0}};
                        bank_rd_addr <= {BANK_ADDR_BITS{1'b0}};  // j=0, step=0
                        acc          <= {ACC_WIDTH{1'b0}};
                        state        <= S_COMPUTE;
                    end else begin
                        fill_idx <= fill_idx + {{(I_WIDTH-1){1'b0}}, 1'b1};
                    end
                end

                // ---------------------------------------------------------
                // COMPUTE: Accumulate K partial products per cycle
                // ---------------------------------------------------------
                S_COMPUTE: begin
                    // Pipeline: step_base_d1 tracks which x values align with BRAM output
                    step_base_d1 <= step_base;

                    if (compute_valid) begin
                        // Accumulate tree_sum (aligned with previous BRAM read)
                        acc <= acc + tree_sum;
                    end

                    if (step_cnt == STEPS_M1) begin
                        // Last step launched — need one more cycle for final accumulation
                        compute_valid <= 1'b1;
                        state         <= S_OUTPUT;
                    end else begin
                        compute_valid <= 1'b1;
                        step_cnt     <= step_cnt + {{(BANK_ADDR_BITS-1){1'b0}}, 1'b1};
                        step_base    <= step_base + K[I_WIDTH-1:0];
                        bank_rd_addr <= j_base_addr + step_cnt + {{(BANK_ADDR_BITS-1){1'b0}}, 1'b1};
                    end
                end

                // ---------------------------------------------------------
                // OUTPUT: Emit result + launch BRAM read for next j (zero-bubble)
                // ---------------------------------------------------------
                S_OUTPUT: begin
                    // Final accumulation from last compute step
                    result_data  <= acc + tree_sum;
                    result_addr  <= j_idx;
                    result_valid <= 1'b1;

                    if (j_idx == LAST_J) begin
                        state <= S_DONE;
                    end else begin
                        // Zero-bubble: set up next j and launch BRAM read
                        // (eliminates S_PREFETCH entirely)
                        j_idx        <= j_idx + {{(J_WIDTH-1){1'b0}}, 1'b1};
                        j_base_addr  <= j_base_addr + STEPS_PER_OUT[BANK_ADDR_BITS-1:0];
                        bank_rd_addr <= j_base_addr + STEPS_PER_OUT[BANK_ADDR_BITS-1:0]; // next j, step 0
                        step_cnt     <= {BANK_ADDR_BITS{1'b0}};
                        step_base    <= {I_WIDTH{1'b0}};
                        acc          <= {ACC_WIDTH{1'b0}};
                        state        <= S_COMPUTE;
                    end
                end

                // ---------------------------------------------------------
                // DONE: Signal completion
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
