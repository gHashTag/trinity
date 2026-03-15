// =============================================================================
// TMU_TOP — Trinity Block-compatible wrapper for TMU
// =============================================================================
// Drop-in replacement for ternary_matvec_bram in trinity_block.v.
// Instantiates TMU with K=16 parallel dot product.
// Swap in trinity_block.v: change module name from ternary_matvec_bram to tmu_top.
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module tmu_top #(
    parameter N_IN            = 243,
    parameter N_OUT           = 729,
    parameter K               = 16,
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
    output wire signed [ACC_WIDTH-1:0] result_data,
    output wire [J_WIDTH-1:0]          result_addr,
    output wire                        result_valid,
    output wire                        done,
    output wire                        busy,
    input  wire signed [ACC_WIDTH-1:0] x_ext_data,
    output wire [I_WIDTH-1:0]          x_ext_addr
);

    tmu #(
        .N_IN           (N_IN),
        .N_OUT          (N_OUT),
        .K              (K),
        .ACC_WIDTH      (ACC_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .I_WIDTH        (I_WIDTH),
        .J_WIDTH        (J_WIDTH),
        .MEM_FILE_PREFIX(MEM_FILE_PREFIX),
        .USE_EXT_X      (USE_EXT_X)
    ) tmu_inst (
        .clk         (clk),
        .rst         (rst),
        .start       (start),
        .result_data (result_data),
        .result_addr (result_addr),
        .result_valid(result_valid),
        .done        (done),
        .busy        (busy),
        .x_ext_data  (x_ext_data),
        .x_ext_addr  (x_ext_addr)
    );

endmodule
