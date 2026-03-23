//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// BRAM DIAGNOSTIC — Minimal test: read from BRAM, check first value, LED
// =============================================================================
// If BRAM init works: mem[0] = 2'b01 (+1) → LED ON
// If BRAM init broken: mem[0] = 2'b00 (0) → LED OFF
// =============================================================================

`timescale 1ns / 1ps

module bram_diag_test (
    input  wire clk,
    output wire led
);

    // Power-on reset
    reg [7:0] por = 8'd0;
    reg       rst = 1'b1;
    always @(posedge clk) begin
        if (por < 8'd255) begin
            por <= por + 1;
            rst <= 1'b1;
        end else
            rst <= 1'b0;
    end

    // BRAM: 177147 x 2-bit, loaded from .mem
    reg [1:0] weight_mem [0:177146];
    initial $readmemb("fpga/openxc7-synth/ternary_matvec_243x729_weights.mem", weight_mem);

    // Read address and data
    reg [17:0] rd_addr;
    reg [1:0]  rd_data;

    always @(posedge clk) begin
        rd_data <= weight_mem[rd_addr];
    end

    // State machine: read first 9 addresses, check pattern 01,10,00,01,10,00,01,10,00
    localparam S_WAIT  = 2'd0;
    localparam S_READ  = 2'd1;
    localparam S_CHECK = 2'd2;
    localparam S_DONE  = 2'd3;

    reg [1:0] state;
    reg [3:0] idx;
    reg       pass;
    reg [7:0] wait_cnt;

    // Expected pattern for first 9 addresses: 01,10,00 repeating
    wire [1:0] expected = (idx % 3 == 0) ? 2'b01 :
                          (idx % 3 == 1) ? 2'b10 :
                                           2'b00 ;

    always @(posedge clk) begin
        if (rst) begin
            state    <= S_WAIT;
            rd_addr  <= 18'd0;
            idx      <= 4'd0;
            pass     <= 1'b1;
            wait_cnt <= 8'd0;
        end else begin
            case (state)
                S_WAIT: begin
                    if (wait_cnt < 8'd10)
                        wait_cnt <= wait_cnt + 1;
                    else begin
                        rd_addr <= 18'd0;
                        idx     <= 4'd0;
                        state   <= S_READ;
                    end
                end

                S_READ: begin
                    // Wait one clock for BRAM read latency
                    state <= S_CHECK;
                end

                S_CHECK: begin
                    if (rd_data != expected)
                        pass <= 1'b0;

                    if (idx == 4'd8) begin
                        state <= S_DONE;
                    end else begin
                        idx     <= idx + 1;
                        rd_addr <= {14'd0, idx} + 18'd1;
                        state   <= S_READ;
                    end
                end

                S_DONE: state <= S_DONE;
            endcase
        end
    end

    // LED: active-low. pass=1 → LED ON (drive 0)
    assign led = ~pass;

endmodule
