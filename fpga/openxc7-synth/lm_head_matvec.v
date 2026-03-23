//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// LM HEAD — Ternary Matrix-Vector for Language Model Output Projection
// =============================================================================
// Computes logits[v] = sum_d W[d][v] * x[d]  where W in {-1, 0, +1}
//
// Architecture: Reuses ternary_matvec_bram core with:
//   N_IN  = DIM   = 243 (hidden dim from last TrinityBlock)
//   N_OUT = VOCAB = 256 (vocabulary size)
//
// Memory layout: column-major, addr = v * DIM + d
//   - 256 * 243 = 62,208 weights x 2 bits = ~15 KB = ~1 BRAM36
//   - BRAM depth: 2^16 = 65,536 (power-of-2)
//   - Latency: 256 * (243 + 2) = ~62.7K clocks = 1.25 ms @ 50 MHz
//
// Weight encoding: 2'b01=+1, 2'b10=-1, 2'b00=0
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module lm_head_matvec #(
    parameter DIM        = 243,
    parameter VOCAB      = 256,
    parameter ACC_WIDTH  = 32,    // wider for logits (no normalization downstream)
    parameter ADDR_WIDTH = 16,    // 2^16 = 65536 >= 256*243 = 62208
    parameter D_WIDTH    = 8,     // ceil(log2(DIM))
    parameter V_WIDTH    = 8,     // ceil(log2(VOCAB))
    parameter MEM_FILE   = "fpga/weights/lm_head_weights.mem",
    parameter USE_EXT_X  = 1
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,

    // Output logits
    output wire signed [ACC_WIDTH-1:0] result_data,
    output wire [V_WIDTH-1:0]          result_addr,
    output wire                        result_valid,
    output wire                        done,
    output wire                        busy,

    // External input (hidden state from last TrinityBlock)
    input  wire signed [19:0]          x_ext_data,   // ACC_WIDTH=20 from blocks
    output wire [D_WIDTH-1:0]          x_ext_addr
);

    // =========================================================================
    // WEIGHT MEMORY — BRAM (inferred by Yosys)
    // =========================================================================
    localparam MEM_DEPTH = 1 << ADDR_WIDTH;  // 65536

    reg [1:0] weight_mem [0:MEM_DEPTH-1];
    initial $readmemb(MEM_FILE, weight_mem);

    reg [ADDR_WIDTH-1:0] rd_addr;
    reg [1:0]            w_code_r;

    // Registered BRAM read
    always @(posedge clk) begin
        w_code_r <= weight_mem[rd_addr];
    end

    // =========================================================================
    // INDEX COUNTERS
    // =========================================================================
    reg [D_WIDTH-1:0]    d_idx;     // input dimension [0..DIM-1]
    reg [V_WIDTH-1:0]    v_idx;     // vocabulary index [0..VOCAB-1]
    reg [ADDR_WIDTH-1:0] base_addr; // v * DIM (incremented, no multiplier)

    localparam [D_WIDTH-1:0] LAST_D = DIM  - 1;
    localparam [V_WIDTH-1:0] LAST_V = VOCAB - 1;

    // Pipeline delay: x_val aligned with BRAM output
    reg signed [ACC_WIDTH-1:0] x_val_d1;

    // External input address
    assign x_ext_addr = d_idx;

    // Sign-extend 20-bit input to ACC_WIDTH (32-bit)
    wire signed [ACC_WIDTH-1:0] x_val_ext = {{(ACC_WIDTH-20){x_ext_data[19]}}, x_ext_data};

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    localparam S_IDLE     = 3'd0;
    localparam S_PREFETCH = 3'd1;
    localparam S_COMPUTE  = 3'd2;
    localparam S_LAST_ACC = 3'd3;
    localparam S_OUTPUT   = 3'd4;
    localparam S_DONE     = 3'd5;

    reg [2:0] state;
    reg signed [ACC_WIDTH-1:0] acc;
    reg                        r_done, r_busy, r_valid;
    reg signed [ACC_WIDTH-1:0] r_data;
    reg [V_WIDTH-1:0]          r_addr;

    assign done        = r_done;
    assign busy        = r_busy;
    assign result_valid = r_valid;
    assign result_data  = r_data;
    assign result_addr  = r_addr;

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            d_idx     <= {D_WIDTH{1'b0}};
            v_idx     <= {V_WIDTH{1'b0}};
            base_addr <= {ADDR_WIDTH{1'b0}};
            acc       <= {ACC_WIDTH{1'b0}};
            rd_addr   <= {ADDR_WIDTH{1'b0}};
            x_val_d1  <= {ACC_WIDTH{1'b0}};
            r_done    <= 1'b0;
            r_busy    <= 1'b0;
            r_valid   <= 1'b0;
            r_data    <= {ACC_WIDTH{1'b0}};
            r_addr    <= {V_WIDTH{1'b0}};
        end else begin
            r_done  <= 1'b0;
            r_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        d_idx     <= {D_WIDTH{1'b0}};
                        v_idx     <= {V_WIDTH{1'b0}};
                        base_addr <= {ADDR_WIDTH{1'b0}};
                        acc       <= {ACC_WIDTH{1'b0}};
                        r_busy    <= 1'b1;
                        rd_addr   <= {ADDR_WIDTH{1'b0}};
                        state     <= S_PREFETCH;
                    end
                end

                S_PREFETCH: begin
                    x_val_d1 <= x_val_ext;
                    d_idx    <= {{(D_WIDTH-1){1'b0}}, 1'b1};
                    rd_addr  <= base_addr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
                    state    <= S_COMPUTE;
                end

                S_COMPUTE: begin
                    case (w_code_r)
                        2'b01: acc <= acc + x_val_d1;
                        2'b10: acc <= acc - x_val_d1;
                        default: ;
                    endcase

                    x_val_d1 <= x_val_ext;

                    if (d_idx == LAST_D) begin
                        state <= S_LAST_ACC;
                    end else begin
                        d_idx   <= d_idx + {{(D_WIDTH-1){1'b0}}, 1'b1};
                        rd_addr <= base_addr + {{(ADDR_WIDTH - D_WIDTH - 1){1'b0}}, d_idx} + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
                    end
                end

                S_LAST_ACC: begin
                    case (w_code_r)
                        2'b01: acc <= acc + x_val_d1;
                        2'b10: acc <= acc - x_val_d1;
                        default: ;
                    endcase
                    state <= S_OUTPUT;
                end

                S_OUTPUT: begin
                    r_data  <= acc;
                    r_addr  <= v_idx;
                    r_valid <= 1'b1;

                    if (v_idx == LAST_V) begin
                        state <= S_DONE;
                    end else begin
                        v_idx     <= v_idx + {{(V_WIDTH-1){1'b0}}, 1'b1};
                        d_idx     <= {D_WIDTH{1'b0}};
                        base_addr <= base_addr + DIM[ADDR_WIDTH-1:0];
                        acc       <= {ACC_WIDTH{1'b0}};
                        rd_addr   <= base_addr + DIM[ADDR_WIDTH-1:0];
                        state     <= S_PREFETCH;
                    end
                end

                S_DONE: begin
                    r_done <= 1'b1;
                    r_busy <= 1'b0;
                    state  <= S_IDLE;
                end
            endcase
        end
    end

endmodule
