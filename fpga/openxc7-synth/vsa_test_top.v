//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════════
// VSA COPROCESSOR TEST TOP
// ═══════════════════════════════════════════════════════════════════════════════
//
// Test module for VSA coprocessor
// Simplified for synthesis verification

module vsa_test_top (
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0]  cmd,
    input  wire       cmd_valid,
    output wire       cmd_ready,
    output wire       busy,
    output wire [31:0] similarity
);

    // Internal BRAM for vector storage (simplified - using registers)
    reg [31:0] vec_mem [0:639];  // 640 words = 10K trits
    reg [13:0] read_addr_a;
    reg [13:0] read_addr_b;
    reg [13:0] write_addr;
    reg [31:0] write_data;
    reg        write_en;

    // VSA coprocessor instance (smaller DIM for test)
    localparam TEST_DIM = 1024;  // Reduced for testing
    localparam BLOCK_SIZE = 16;

    wire [13:0] vec_addr_a;
    wire [13:0] vec_addr_b;
    wire [31:0] vec_data_a;
    wire [31:0] vec_data_b;
    wire [31:0] vec_wr_data;
    wire        vec_wr_en;
    wire [13:0] result_addr;
    wire        result_valid;
    wire [31:0] similarity_out;

    vsa_coprocessor #(
        .DIM(TEST_DIM),
        .BLOCK_SIZE(BLOCK_SIZE)
    ) coproc (
        .clk(clk),
        .rst_n(~rst),
        .cmd(cmd),
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .vec_addr_a(vec_addr_a),
        .vec_addr_b(vec_addr_b),
        .vec_data_a(vec_data_a),
        .vec_data_b(vec_data_b),
        .vec_wr_data(vec_wr_data),
        .vec_wr_en(vec_wr_en),
        .result_addr(result_addr),
        .result_valid(result_valid),
        .busy(busy),
        .similarity_out(similarity)
    );

    // Simple BRAM simulation
    assign vec_data_a = vec_mem[vec_addr_a];
    assign vec_data_b = vec_mem[vec_addr_b];

    always @(posedge clk) begin
        if (vec_wr_en) begin
            vec_mem[result_addr] <= vec_wr_data;
        end
    end

    // Initialize with test data
    integer j;
    initial begin
        for (j = 0; j < 640; j = j + 1) begin
            vec_mem[j] = 32'h00000000;  // All zeros
        end
    end

endmodule
