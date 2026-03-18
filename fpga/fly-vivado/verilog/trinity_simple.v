// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY FPGA — Minimal Test Module (Icarus Verilog Compatible)
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module trinity_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [31:0] data_in,
    output reg  [31:0] data_out,
    output reg         valid_out,
    output wire        ready,
    output wire [3:0]  led,
    output wire [15:0] gpio
);

    // State machine
    localparam IDLE    = 2'd0;
    localparam PROCESS = 2'd1;
    localparam DONE    = 2'd2;

    reg [1:0] state;
    reg [31:0] cycle_counter;

    // Sacred constants (Q16.16 fixed point)
    wire [31:0] PHI;
    wire [31:0] PHI_SQ;
    wire [31:0] TRINITY;

    assign PHI     = 32'h00019E38;  // 1.618034
    assign PHI_SQ  = 32'h00029E1F;  // 2.618034
    assign TRINITY = 32'h00030000;  // 3.0

    assign ready = (state == IDLE);

    // LED heartbeat
    assign led[0] = cycle_counter[20];
    assign led[1] = cycle_counter[22];
    assign led[2] = cycle_counter[24];
    assign led[3] = (state == DONE);

    // GPIO outputs
    assign gpio[3:0]   = 4'h3;      // TRINITY
    assign gpio[7:4]   = 4'hE;      // First hex of 999
    assign gpio[11:8]  = 4'h1;      // First hex of PHI
    assign gpio[15:12] = 4'h2;      // First hex of PHI²

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            data_out <= 32'd0;
            valid_out <= 1'b0;
            cycle_counter <= 32'd0;
        end else begin
            cycle_counter <= cycle_counter + 1;

            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    if (valid_in) begin
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    case (data_in[3:0])
                        4'h1: data_out <= PHI;       // Read PHI
                        4'h2: data_out <= PHI_SQ;    // Read PHI²
                        4'h3: data_out <= TRINITY;   // Read TRINITY
                        default: data_out <= cycle_counter;
                    endcase
                    state <= DONE;
                end

                DONE: begin
                    valid_out <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
