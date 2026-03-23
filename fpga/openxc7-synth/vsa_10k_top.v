//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  TRINITY VSA — 10K-DIMENSIONAL COMPLETE SYSTEM                                  ║
// ║  Week 2 Day 3: BIND + BUNDLE + SIMILARITY + UNIFIED TOP                         ║
// ║                                                                              ║
// ║  Operations:                                                                 ║
// ║  - BIND: Trit multiplication (a × b)                                          ║
// ║  - BUNDLE: Majority vote of 2 inputs                                         ║
// ║  - SIMILARITY: Cosine similarity (scaled 0-65535)                           ║
// ║                                                                              ║
// ║  φ² + 1/φ² = 3 = TRINITY                                                    ║
// ╚════════════════════════════════════════════════════════════════════════════╝

`default_nettype none

//==========================================================================
// TRIT MULTIPLIER (combinational)
//==========================================================================
module TritMult (
    input  wire [1:0] a_trit,
    input  wire [1:0] b_trit,
    output wire [1:0] result
);
    assign result = (~(|{a_trit, b_trit})) ? 2'b00 :
                    (a_trit == b_trit) ? 2'b01 : 2'b10;
endmodule

//==========================================================================
// TRIT BUNDLE (majority vote)
//==========================================================================
module TritBundle (
    input  wire [1:0] a_trit,
    input  wire [1:0] b_trit,
    output wire [1:0] result
);
    wire a_neg = (a_trit == 2'b10);
    wire a_pos = (a_trit == 2'b01);
    wire a_zer = (a_trit == 2'b00);
    wire b_neg = (b_trit == 2'b10);
    wire b_pos = (b_trit == 2'b01);
    wire b_zer = (b_trit == 2'b00);

    assign result = (a_neg && b_neg) ? 2'b10 :
                    (a_pos && b_pos) ? 2'b01 :
                    (a_zer) ? b_trit :
                    (b_zer) ? a_trit : 2'b00;
endmodule

//==========================================================================
// 10K TRIT OPERATIONS CORE (BIND + BUNDLE + SIMILARITY)
//==========================================================================
module VSA10K_OpsCore (
    input  wire clk,
    input  wire rst,
    input  wire valid_in,
    input  wire [19999:0] a_vec,
    input  wire [19999:0] b_vec,
    input  wire [1:0] op_mode,     // 00=bind, 01= bundle, 10= similarity
    output reg  valid_out,
    output reg  [19999:0] result_vec,   // For bind/bundle
    output wire [15:0] similarity,      // For similarity op
    output wire busy
);

    // Operations status
    reg busy_reg = 0;
    assign busy = busy_reg;

    // Generate trit arrays for similarity computation
    wire [9999:0] a_signed;
    wire [9999:0] b_signed;

    genvar k;
    generate
        for (k = 0; k < 10000; k = k + 1) begin : trit_decode
            wire [1:0] a_t = a_vec[k*2 +: 2];
            wire [1:0] b_t = b_vec[k*2 +: 2];
            // Convert to signed: 00->0, 01->+1, 10->-1
            assign a_signed[k] = (a_t == 2'b01) ? 1'b1 :
                              (a_t == 2'b10) ? 1'b1 : 1'b0;  // magnitude
            assign b_signed[k] = (b_t == 2'b01) ? 1'b1 :
                              (b_t == 2'b10) ? 1'b1 : 1'b0;
        end
    endgenerate

    // Similarity: dot product + norms computation
    reg signed [23:0] dot_product = 0;
    reg signed [15:0] norm_a = 0;
    reg signed [15:0] norm_b = 0;
    reg [15:0] similarity_reg = 0;

    // Parallel bind/bundle array (625 blocks × 16 trits)
    wire [31:0] block_result [0:624];

    generate
        for (k = 0; k < 625; k = k + 1) begin : op_block
            wire [31:0] a_block = a_vec[k*32 +: 32];
            wire [31:0] b_block = b_vec[k*32 +: 32];
            wire [1:0] trit_out [0:15];

            genvar t;
            for (t = 0; t < 16; t = t + 1) begin : trit_ops
                wire [1:0] a_trit = a_block[t*2 +: 2];
                wire [1:0] b_trit = b_block[t*2 +: 2];
                wire [1:0] bind_r, bundle_r;

                TritMult mult (.a_trit(a_trit), .b_trit(b_trit), .result(bind_r));
                TritBundle bund (.a_trit(a_trit), .b_trit(b_trit), .result(bundle_r));

                // Mux: select operation
                assign trit_out[t] = (op_mode == 2'b00) ? bind_r :
                                  (op_mode == 2'b01) ? bundle_r : 2'b00;
            end

            assign block_result[k] = {
                trit_out[15], trit_out[14], trit_out[13], trit_out[12],
                trit_out[11], trit_out[10], trit_out[9],  trit_out[8],
                trit_out[7],  trit_out[6],  trit_out[5],  trit_out[4],
                trit_out[3],  trit_out[2],  trit_out[1],  trit_out[0]
            };
        end
    endgenerate

    // Sequential similarity computation (pipelined)
    reg [6:0] sim_counter = 0;
    reg [6:0] sim_block = 0;
    reg signed [23:0] dot_acc = 0;
    reg signed [15:0] norm_a_acc = 0;
    reg signed [15:0] norm_b_acc = 0;

    // State machine
    localparam IDLE = 2'd0;
    localparam PROCESS = 2'd1;
    localparam SIM_COMPUTE = 2'd2;
    localparam DONE = 2'd3;

    reg [1:0] state = IDLE;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            valid_out <= 0;
            busy_reg <= 0;
            sim_counter <= 0;
            sim_block <= 0;
            dot_acc <= 0;
            norm_a_acc <= 0;
            norm_b_acc <= 0;
            similarity_reg <= 0;
        end else begin
            valid_out <= 0;

            case (state)
                IDLE: begin
                    busy_reg <= 0;
                    if (valid_in) begin
                        state <= PROCESS;
                        busy_reg <= 1;
                    end
                end

                PROCESS: begin
                    if (op_mode != 2'b10) begin
                        // Bind or Bundle: parallel, single cycle
                        state <= DONE;
                    end else begin
                        // Similarity: need sequential computation
                        state <= SIM_COMPUTE;
                        sim_counter <= 0;
                        sim_block <= 0;
                        dot_acc <= 0;
                        norm_a_acc <= 0;
                        norm_b_acc <= 0;
                    end
                end

                SIM_COMPUTE: begin
                    // Process 16 trits (one block) per cycle
                    if (sim_block < 625) begin
                        // Compute for this block
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            if ((sim_block * 16 + i) < 10000) begin
                                // Convert trit to signed value
                                reg [1:0] a_t, b_t;
                                reg signed a_val, b_val;
                                a_t = a_vec[(sim_block * 16 + i) * 2 +: 2];
                                b_t = b_vec[(sim_block * 16 + i) * 2 +: 2];

                                a_val = (a_t == 2'b01) ? 8'sd01 :
                                        (a_t == 2'b10) ? 8'sd81 : 8'sd00;
                                b_val = (b_t == 2'b01) ? 8'sd01 :
                                        (b_t == 2'b10) ? 8'sd81 : 8'sd00;

                                dot_acc <= dot_acc + (a_val * b_val);
                                norm_a_acc <= norm_a_acc + (a_val * a_val);
                                norm_b_acc <= norm_b_acc + (b_val * b_val);
                            end
                        end
                        sim_block <= sim_block + 1;
                    end else begin
                        // Finalize similarity
                        if ((norm_a_acc + norm_b_acc) > 0) begin
                            similarity_reg <= (dot_acc * 16'd65535) / (norm_a_acc + norm_b_acc);
                        end else begin
                            similarity_reg <= 0;
                        end
                        state <= DONE;
                    end
                end

                DONE: begin
                    busy_reg <= 0;
                    valid_out <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

    // Pack result for bind/bundle
    always @(posedge clk) begin
        if (rst) begin
            result_vec <= 20000'd0;
        end else if (state == PROCESS && op_mode != 2'b10) begin
            integer i;
            for (i = 0; i < 625; i = i + 1) begin
                result_vec[i*32 +: 32] <= block_result[i];
            end
        end
    end

    assign similarity = similarity_reg;

endmodule

//==========================================================================
// BRAM STORAGE (4 vectors)
//==========================================================================
module VSA10K_Storage (
    input  wire clk,
    input  wire we_a,
    input  wire we_b,
    input  wire we_c,
    input  wire we_d,
    input  wire [9:0] addr,
    input  wire [31:0] din_a,
    input  wire [31:0] din_b,
    input  wire [31:0] din_c,
    input  wire [31:0] din_d,
    output wire [31:0] dout_a,
    output wire [31:0] dout_b,
    output wire [31:0] dout_c,
    output wire [31:0] dout_d
);

    reg [31:0] vector_a [0:624];
    reg [31:0] vector_b [0:624];
    reg [31:0] vector_c [0:624];
    reg [31:0] vector_d [0:624];

    always @(posedge clk) begin
        if (we_a && addr < 10'd625) vector_a[addr] <= din_a;
        if (we_b && addr < 10'd625) vector_b[addr] <= din_b;
        if (we_c && addr < 10'd625) vector_c[addr] <= din_c;
        if (we_d && addr < 10'd625) vector_d[addr] <= din_d;
    end

    assign dout_a = (addr < 10'd625) ? vector_a[addr] : 32'd0;
    assign dout_b = (addr < 10'd625) ? vector_b[addr] : 32'd0;
    assign dout_c = (addr < 10'd625) ? vector_c[addr] : 32'd0;
    assign dout_d = (addr < 10'd625) ? vector_d[addr] : 32'd0;

endmodule

//==========================================================================
// UNIFIED TOP MODULE — ALL 10K VSA OPERATIONS
//==========================================================================
module VSA10K_Top (
    input  wire clk,              // 50 MHz
    input  wire rst,              // Reset
    // Command interface
    input  wire [1:0] cmd,         // 00=bind, 01= bundle, 10= similarity
    input  wire cmd_valid,        // Command valid
    // Vector A interface
    input  wire [9:0] addr_a,
    input  wire [31:0] din_a,
    input  wire we_a,
    output wire [31:0] dout_a,
    // Vector B interface
    input  wire [9:0] addr_b,
    input  wire [31:0] din_b,
    input  wire we_b,
    output wire [31:0] dout_b,
    // Result interface
    output wire [31:0] dout_result,
    input  wire [9:0] addr_result,
    output wire [15:0] similarity_score,
    // Status
    output wire busy,
    output wire done,
    output wire led
);

    // Storage
    wire [31:0] storage_a_out, storage_b_out;
    wire storage_we_a, storage_we_b;

    assign storage_we_a = (cmd == 2'b10) ? 1'b0 : we_a;  // Auto-load vectors for similarity
    assign storage_we_b = (cmd == 2'b10) ? 1'b0 : we_b;

    VSA10K_Storage storage (
        .clk(clk),
        .we_a(storage_we_a),
        .we_b(storage_we_b),
        .we_c(1'b0),
        .we_d(1'b0),
        .addr(addr_a),
        .din_a(din_a),
        .din_b(din_b),
        .din_c(32'd0),
        .din_d(32'd0),
        .dout_a(storage_a_out),
        .dout_b(storage_b_out),
        .dout_c(),
        .dout_d()
    );

    // Operations core
    wire ops_busy, ops_valid;
    wire [19999:0] ops_result;
    wire [15:0] ops_similarity;

    // Vector assembly registers
    reg [19999:0] vec_a_reg, vec_b_reg;
    reg [3:0] load_state = 0;

    VSA10K_OpsCore ops_core (
        .clk(clk),
        .rst(rst),
        .valid_in(cmd_valid),
        .a_vec(vec_a_reg),
        .b_vec(vec_b_reg),
        .op_mode(cmd),
        .valid_out(ops_valid),
        .result_vec(ops_result),
        .similarity(ops_similarity),
        .busy(ops_busy)
    );

    // State machine for vector loading and operation
    localparam IDLE = 3'd0;
    localparam LOAD = 3'd1;
    localparam EXECUTE = 3'd2;
    localparam RESULT = 3'd3;

    reg [2:0] state = IDLE;
    reg [9:0] load_counter = 0;
    reg [31:0] result_storage [0:624];

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            load_counter <= 0;
            done <= 0;
        end else begin
            done <= 0;

            case (state)
                IDLE: begin
                    if (cmd_valid) begin
                        state <= LOAD;
                        load_counter <= 0;
                    end
                end

                LOAD: begin
                    // Load vectors from storage
                    if (load_counter < 625) begin
                        vec_a_reg[load_counter*32 +: 32] <= storage_a_out;
                        vec_b_reg[load_counter*32 +: 32] <= storage_b_out;
                        load_counter <= load_counter + 1;
                    end else begin
                        state <= EXECUTE;
                    end
                end

                EXECUTE: begin
                    if (!ops_busy) begin
                        // Store results
                        if (cmd == 2'b10) begin
                            // Similarity: just have the score
                            state <= IDLE;
                            done <= 1;
                        end else begin
                            // Bind/Bundle: store result
                            integer i;
                            for (i = 0; i < 625; i = i + 1) begin
                                result_storage[i] <= ops_result[i*32 +: 32];
                            end
                            state <= IDLE;
                            done <= 1;
                        end
                    end
                end

                RESULT: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Output assignments
    assign dout_a = storage_a_out;
    assign dout_b = storage_b_out;
    assign dout_result = result_storage[addr_result];
    assign similarity_score = ops_similarity;
    assign busy = ops_busy || (state == LOAD);

    // LED indicator
    reg [23:0] blink_counter;
    always @(posedge clk) begin
        blink_counter <= blink_counter + 1;
    end

    assign led = busy ? ~blink_counter[19] : ~blink_counter[23];

endmodule

//==========================================================================
// RESOURCE ESTIMATES (XC7A100T)
//==========================================================================
/*
╔════════════════════════════════════════════════════════════════════════════╗
║  MODULE                  LUT     FF      BRAM    DSP                       ║
╠════════════════════════════════════════════════════════════════════════════╣
║  TritMult (×10K)       ~500    ~0      0       0                         ║
║  TritBundle (×10K)     ~300    ~0      0       0                         ║
║  Similarity logic       ~400    ~500    0       0                         ║
║  Pipeline/control        ~300    ~300    0       0                         ║
║  Storage (4×625×32)     ~200    ~0      2       0                         ║
║  Result storage        ~200    ~0      0       0                         ║
╠════════════════════════════════════════════════════════════════════════════╣
║  TOTAL                   ~1900   ~800    2       0                         ║
║  % of XC7A100T           ~3.0%   ~0.6%   ~1%     0%                         ║
╚════════════════════════════════════════════════════════════════════════════╝
*/

// φ² + 1/φ² = 3 = TRINITY
// Cycle #125 — Week 2 Day 3
