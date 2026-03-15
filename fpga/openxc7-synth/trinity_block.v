// =============================================================================
// TRINITY BLOCK — Reusable Transformer Block for FPGA
// =============================================================================
// Complete TrinityBlock forward pass:
//   input[N_SMALL] → MatVec1(N_SMALL→N_LARGE) → ReLU → Buffer
//                  → MatVec2(N_LARGE→N_SMALL) → +input (Residual) → RMSNorm
//                  → output[N_SMALL]
//
// Interface:
//   Fill phase: block reads external input via x_rd_addr/x_rd_data (N_SMALL cycles)
//   Then autonomous compute (~27K clocks with TMU K=16)
//   Streaming normalized output via out_valid/out_data/out_addr
//   done pulse = all outputs emitted
//
// Resources: ~3.5K LUT, ~32 BRAM36, 0 DSP48 (with TMU K=16)
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module trinity_block #(
    parameter N_SMALL       = 243,
    parameter N_LARGE       = 729,
    parameter ACC_WIDTH     = 20,
    parameter FRAC_BITS     = 8,
    parameter ADDR_WIDTH    = 18,
    parameter I_UP_WIDTH    = 8,     // ceil(log2(N_SMALL))
    parameter J_UP_WIDTH    = 10,    // ceil(log2(N_LARGE))
    parameter I_DOWN_WIDTH  = 10,    // ceil(log2(N_LARGE))
    parameter J_DOWN_WIDTH  = 8,     // ceil(log2(N_SMALL))
    parameter MEM_FILE_UP_PREFIX   = "tmu_w_up",
    parameter MEM_FILE_DOWN_PREFIX = "tmu_w_down"
)(
    input  wire                        clk,
    input  wire                        rst,
    input  wire                        start,

    // External input read port (active during fill phase)
    output reg  [J_DOWN_WIDTH-1:0]     x_rd_addr,
    input  wire signed [ACC_WIDTH-1:0] x_rd_data,

    // Normalized output stream
    output wire                        out_valid,
    output wire signed [ACC_WIDTH-1:0] out_data,
    output wire [J_DOWN_WIDTH-1:0]     out_addr,

    // Control
    output reg                         busy,
    output reg                         done
);

    // =========================================================================
    // INPUT BUFFER — stores external input for matvec1 and residual
    // =========================================================================
    localparam INPUT_BUF_DEPTH = 256;
    reg signed [ACC_WIDTH-1:0] input_buffer [0:INPUT_BUF_DEPTH-1];

    // matvec1 reads from input_buffer
    wire [I_UP_WIDTH-1:0] mv1_x_addr;
    wire signed [ACC_WIDTH-1:0] mv1_x_data;
    assign mv1_x_data = input_buffer[mv1_x_addr];

    // Residual reads from input_buffer
    wire [J_DOWN_WIDTH-1:0] mv2_addr_out;
    wire signed [ACC_WIDTH-1:0] res_rd_data;
    assign res_rd_data = input_buffer[mv2_addr_out];

    // =========================================================================
    // STAGE 1: MATVEC1 (N_SMALL → N_LARGE)
    // =========================================================================
    wire signed [ACC_WIDTH-1:0] mv1_data;
    wire [J_UP_WIDTH-1:0]       mv1_addr;
    wire                        mv1_valid;
    wire                        mv1_done;
    wire                        mv1_busy;
    reg                         mv1_start;

    tmu_top #(
        .N_IN           (N_SMALL),
        .N_OUT          (N_LARGE),
        .K              (16),
        .ACC_WIDTH      (ACC_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .I_WIDTH        (I_UP_WIDTH),
        .J_WIDTH        (J_UP_WIDTH),
        .MEM_FILE_PREFIX(MEM_FILE_UP_PREFIX),
        .USE_EXT_X      (1)
    ) matvec1 (
        .clk         (clk),
        .rst         (rst),
        .start       (mv1_start),
        .result_data (mv1_data),
        .result_addr (mv1_addr),
        .result_valid(mv1_valid),
        .done        (mv1_done),
        .busy        (mv1_busy),
        .x_ext_data  (mv1_x_data),
        .x_ext_addr  (mv1_x_addr)
    );

    // =========================================================================
    // STAGE 2: ReLU ACTIVATION
    // =========================================================================
    wire                        relu_valid;
    wire signed [ACC_WIDTH-1:0] relu_data;
    wire                        relu_done;

    ternary_activation #(.WIDTH(ACC_WIDTH)) activation (
        .clk(clk), .rst(rst),
        .valid_in(mv1_valid), .data_in(mv1_data), .done_in(mv1_done),
        .valid_out(relu_valid), .data_out(relu_data), .done_out(relu_done)
    );

    reg [J_UP_WIDTH-1:0] mv1_addr_d1;
    always @(posedge clk) mv1_addr_d1 <= mv1_addr;

    // =========================================================================
    // INTERMEDIATE BUFFER — N_LARGE x ACC_WIDTH
    // =========================================================================
    localparam RELU_BUF_DEPTH = 1024;
    reg signed [ACC_WIDTH-1:0] relu_buffer [0:RELU_BUF_DEPTH-1];

    always @(posedge clk) begin
        if (relu_valid)
            relu_buffer[mv1_addr_d1] <= relu_data;
    end

    wire [I_DOWN_WIDTH-1:0] mv2_x_addr;
    wire signed [ACC_WIDTH-1:0] mv2_x_data;
    assign mv2_x_data = relu_buffer[mv2_x_addr];

    // =========================================================================
    // STAGE 3: MATVEC2 (N_LARGE → N_SMALL)
    // =========================================================================
    wire signed [ACC_WIDTH-1:0] mv2_data;
    wire                        mv2_valid;
    wire                        mv2_done;
    wire                        mv2_busy;
    reg                         mv2_start;

    tmu_top #(
        .N_IN           (N_LARGE),
        .N_OUT          (N_SMALL),
        .K              (16),
        .ACC_WIDTH      (ACC_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .I_WIDTH        (I_DOWN_WIDTH),
        .J_WIDTH        (J_DOWN_WIDTH),
        .MEM_FILE_PREFIX(MEM_FILE_DOWN_PREFIX),
        .USE_EXT_X      (1)
    ) matvec2 (
        .clk         (clk),
        .rst         (rst),
        .start       (mv2_start),
        .result_data (mv2_data),
        .result_addr (mv2_addr_out),
        .result_valid(mv2_valid),
        .done        (mv2_done),
        .busy        (mv2_busy),
        .x_ext_data  (mv2_x_data),
        .x_ext_addr  (mv2_x_addr)
    );

    // =========================================================================
    // STAGE 4: RESIDUAL CONNECTION
    // =========================================================================
    wire signed [ACC_WIDTH-1:0] residual_data;
    assign residual_data = mv2_data + res_rd_data;

    // =========================================================================
    // STAGE 5: RMS NORM
    // =========================================================================
    wire norm_done_int;

    ternary_rmsnorm #(
        .WIDTH    (ACC_WIDTH),
        .N        (N_SMALL),
        .ADDR_W   (J_DOWN_WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .LOG2_N   (8)
    ) rmsnorm (
        .clk      (clk),
        .rst      (rst),
        .in_valid (mv2_valid),
        .in_data  (residual_data),
        .in_addr  (mv2_addr_out),
        .in_done  (mv2_done),
        .out_valid(out_valid),
        .out_data (out_data),
        .out_addr (out_addr),
        .out_done (norm_done_int)
    );

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    localparam S_IDLE    = 3'd0;
    localparam S_FILL    = 3'd1;
    localparam S_START1  = 3'd2;
    localparam S_LAYER1  = 3'd3;
    localparam S_START2  = 3'd4;
    localparam S_LAYER2  = 3'd5;
    localparam S_NORM    = 3'd6;
    localparam S_DONE    = 3'd7;

    reg [2:0] state;

    // Width-safe comparison constant
    localparam [J_DOWN_WIDTH-1:0] LAST_INPUT = N_SMALL - 1;

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            busy      <= 1'b0;
            done      <= 1'b0;
            mv1_start <= 1'b0;
            mv2_start <= 1'b0;
            x_rd_addr <= {J_DOWN_WIDTH{1'b0}};
        end else begin
            mv1_start <= 1'b0;
            mv2_start <= 1'b0;
            done      <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        busy      <= 1'b1;
                        x_rd_addr <= {J_DOWN_WIDTH{1'b0}};
                        state     <= S_FILL;
                    end
                end

                // Fill input_buffer from external source
                S_FILL: begin
                    input_buffer[x_rd_addr] <= x_rd_data;
                    if (x_rd_addr == LAST_INPUT) begin
                        state <= S_START1;
                    end else begin
                        x_rd_addr <= x_rd_addr + {{(J_DOWN_WIDTH-1){1'b0}}, 1'b1};
                    end
                end

                S_START1: begin
                    mv1_start <= 1'b1;
                    state     <= S_LAYER1;
                end

                S_LAYER1: begin
                    if (relu_done)
                        state <= S_START2;
                end

                S_START2: begin
                    mv2_start <= 1'b1;
                    state     <= S_LAYER2;
                end

                // matvec2 runs, residual + rmsnorm feed inline
                S_LAYER2: begin
                    if (mv2_done)
                        state <= S_NORM;
                end

                // Wait for rmsnorm to emit all normalized outputs
                S_NORM: begin
                    if (norm_done_int) begin
                        done  <= 1'b1;
                        busy  <= 1'b0;
                        state <= S_DONE;
                    end
                end

                S_DONE: state <= S_DONE;
            endcase
        end
    end

endmodule
