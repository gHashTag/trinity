//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// TERNARY MATRIX-VECTOR MULTIPLY — BRAM-Backed Accelerator Core
// =============================================================================
// Computes y[j] = sum_i W[i][j] * x[i]  where W[i][j] in {-1, 0, +1}
//
// Architecture: Sequential with pipelined BRAM read
//   - Weights stored in BRAM (inferred), loaded via $readmemb
//   - Single accumulator, one weight read per clock
//   - BRAM read latency: 1 clock (pipelined — no throughput loss)
//   - Outer loop: j = 0..N_OUT-1 (output index)
//   - Inner loop: i = 0..N_IN-1 (input/accumulation index)
//   - Total latency: N_OUT * (N_IN + 2) + overhead clocks
//   - No DSP48 — pure add/sub
//
// Default: 243x729 (HSLM TrinityBlock up-projection)
//   - 177,147 weights x 2 bits = ~43 KB = ~12 BRAM36
//   - Latency: ~179K clocks = 3.6 ms @ 50 MHz
//
// Weight encoding: 2'b01=+1, 2'b10=-1, 2'b00=0
// Memory layout: column-major, addr = j * N_IN + i
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module ternary_matvec_bram #(
    parameter N_IN       = 243,
    parameter N_OUT      = 729,
    parameter ACC_WIDTH  = 20,
    parameter ADDR_WIDTH = 18,
    parameter I_WIDTH    = 8,
    parameter J_WIDTH    = 10,
    parameter MEM_FILE   = "ternary_matvec_243x729_weights.mem",
    parameter USE_EXT_X  = 0     // 0 = x[i]=i+1 (self-test), 1 = external input
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,
    output reg signed [ACC_WIDTH-1:0] result_data,
    output reg  [J_WIDTH-1:0]      result_addr,
    output reg                     result_valid,
    output reg                     done,
    output reg                     busy,
    // External input (used when USE_EXT_X=1)
    input  wire signed [ACC_WIDTH-1:0] x_ext_data,  // combinational read from buffer
    output wire [I_WIDTH-1:0]          x_ext_addr   // address into input buffer
);

    // =========================================================================
    // WEIGHT MEMORY — BRAM (inferred by Yosys)
    // =========================================================================
    // Power-of-2 depth for clean BRAM cascade address decode.
    // N_IN*N_OUT = 177,147 but we declare 2^ADDR_WIDTH = 262,144.
    // Unused entries default to 0 (no contribution to accumulation).
    localparam MEM_DEPTH = 1 << ADDR_WIDTH;  // 262,144

    reg [1:0] weight_mem [0:MEM_DEPTH-1];
    initial $readmemb(MEM_FILE, weight_mem);

    reg [ADDR_WIDTH-1:0] rd_addr;
    reg [1:0]            w_code_r;

    // Registered BRAM read — 1 clock latency
    always @(posedge clk) begin
        w_code_r <= weight_mem[rd_addr];
    end

    // =========================================================================
    // INDEX COUNTERS
    // =========================================================================
    reg [I_WIDTH-1:0]    i_idx;
    reg [J_WIDTH-1:0]    j_idx;
    reg [ADDR_WIDTH-1:0] base_addr;   // j * N_IN (incremented, no multiplier)

    // Width-safe comparison constants (avoid 32-bit literal promotion bug)
    localparam [I_WIDTH-1:0] LAST_I = N_IN  - 1;
    localparam [J_WIDTH-1:0] LAST_J = N_OUT - 1;

    // Pipeline delay: x_val aligned with BRAM output
    reg signed [ACC_WIDTH-1:0] x_val_d1;

    // External input address (always driven, used when USE_EXT_X=1)
    assign x_ext_addr = i_idx;

    // Input value selection: self-test (i+1) or external buffer
    wire signed [ACC_WIDTH-1:0] x_val_next;
    generate
        if (USE_EXT_X) begin : gen_ext_x
            assign x_val_next = x_ext_data;
        end else begin : gen_self_x
            assign x_val_next = {{(ACC_WIDTH - I_WIDTH - 1){1'b0}}, i_idx} + {{(ACC_WIDTH-1){1'b0}}, 1'b1};
        end
    endgenerate

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

    always @(posedge clk) begin
        if (rst) begin
            state        <= S_IDLE;
            i_idx        <= {I_WIDTH{1'b0}};
            j_idx        <= {J_WIDTH{1'b0}};
            base_addr    <= {ADDR_WIDTH{1'b0}};
            acc          <= {ACC_WIDTH{1'b0}};
            rd_addr      <= {ADDR_WIDTH{1'b0}};
            x_val_d1     <= {ACC_WIDTH{1'b0}};
            done         <= 1'b0;
            busy         <= 1'b0;
            result_valid <= 1'b0;
            result_data  <= {ACC_WIDTH{1'b0}};
            result_addr  <= {J_WIDTH{1'b0}};
        end else begin
            done         <= 1'b0;
            result_valid <= 1'b0;

            case (state)
                // ---------------------------------------------------------
                // IDLE: Wait for start signal
                // ---------------------------------------------------------
                S_IDLE: begin
                    if (start) begin
                        i_idx     <= {I_WIDTH{1'b0}};
                        j_idx     <= {J_WIDTH{1'b0}};
                        base_addr <= {ADDR_WIDTH{1'b0}};
                        acc       <= {ACC_WIDTH{1'b0}};
                        busy      <= 1'b1;
                        rd_addr   <= {ADDR_WIDTH{1'b0}};  // addr for weight[0][0]
                        state     <= S_PREFETCH;
                    end
                end

                // ---------------------------------------------------------
                // PREFETCH: Wait 1 clock for BRAM data to appear
                //           Meanwhile, prepare x_val and advance i
                // ---------------------------------------------------------
                S_PREFETCH: begin
                    // x_val for i=0 will be used next cycle with registered weight
                    x_val_d1 <= x_val_next;
                    // Advance to i=1
                    i_idx    <= {{(I_WIDTH-1){1'b0}}, 1'b1};
                    rd_addr  <= base_addr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
                    state    <= S_COMPUTE;
                end

                // ---------------------------------------------------------
                // COMPUTE: Accumulate weight[i-1]*x[i-1] from BRAM output
                //          Simultaneously launch read for weight[i]
                // ---------------------------------------------------------
                S_COMPUTE: begin
                    // Accumulate using registered weight (aligned with x_val_d1)
                    case (w_code_r)
                        2'b01: acc <= acc + x_val_d1;  // +1
                        2'b10: acc <= acc - x_val_d1;  // -1
                        default: ;                      //  0
                    endcase

                    // Prepare next x_val (pipeline delay)
                    x_val_d1 <= x_val_next;

                    if (i_idx == LAST_I) begin
                        // Last input index — one more accumulation pending
                        state <= S_LAST_ACC;
                    end else begin
                        // Advance to next input
                        i_idx   <= i_idx + {{(I_WIDTH-1){1'b0}}, 1'b1};
                        rd_addr <= base_addr + {{(ADDR_WIDTH - I_WIDTH - 1){1'b0}}, i_idx} + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
                    end
                end

                // ---------------------------------------------------------
                // LAST_ACC: Accumulate the final weight for this column
                // ---------------------------------------------------------
                S_LAST_ACC: begin
                    case (w_code_r)
                        2'b01: acc <= acc + x_val_d1;
                        2'b10: acc <= acc - x_val_d1;
                        default: ;
                    endcase
                    state <= S_OUTPUT;
                end

                // ---------------------------------------------------------
                // OUTPUT: Emit result for column j, advance to next column
                // ---------------------------------------------------------
                S_OUTPUT: begin
                    result_data  <= acc;
                    result_addr  <= j_idx;
                    result_valid <= 1'b1;

                    if (j_idx == LAST_J) begin
                        // All columns done
                        state <= S_DONE;
                    end else begin
                        // Next column: j increments, i resets to 0
                        j_idx     <= j_idx + {{(J_WIDTH-1){1'b0}}, 1'b1};
                        i_idx     <= {I_WIDTH{1'b0}};
                        base_addr <= base_addr + N_IN[ADDR_WIDTH-1:0];
                        acc       <= {ACC_WIDTH{1'b0}};
                        rd_addr   <= base_addr + N_IN[ADDR_WIDTH-1:0];
                        state     <= S_PREFETCH;
                    end
                end

                // ---------------------------------------------------------
                // DONE: Signal completion
                // ---------------------------------------------------------
                S_DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
