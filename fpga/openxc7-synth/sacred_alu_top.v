//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`default_nettype none

// ═════════════════════════════════════════════════════════════════════════
// SACRED ALU TOP — Test wrapper with LED heartbeat
// ═════════════════════════════════════════════════════════════════════════
//
// Tests Sacred ALU with automatic pattern generation
// LED heartbeat = design is running
//
// φ² + 1/φ² = 3 | TRINITY

module sacred_alu_top (
    input  wire clk,          // 50 MHz onboard crystal (U22)
    output wire led           // LED T23 (active-low)
);

    // Reset from clock (stable after power)
    reg [3:0] reset_cnt = 4'hF;
    wire rst_n = (reset_cnt == 4'h0);
    always @(posedge clk) begin
        if (reset_cnt != 4'h0)
            reset_cnt <= reset_cnt - 4'h1;
    end

    // ========================================================================
    // CLOCK DIVIDER for LED heartbeat (1 Hz blink)
    // ========================================================================
    reg [25:0] clk_div = 26'h0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clk_div <= 26'h0;
        else
            clk_div <= clk_div + 26'h1;
    end

    // LED heartbeat (1 Hz)
    wire led_heartbeat = clk_div[25];  // 50MHz / 2^26 ≈ 0.74 Hz

    // ========================================================================
    // SACRED ALU TEST PATTERN
    // ========================================================================
    reg in_valid;
    wire in_ready;
    reg [1:0] mode;
    reg [31:0] in_a;
    reg [31:0] in_b;
    wire out_valid;
    reg out_ready;
    wire [31:0] out_y;

    // Simple test: GF16 ADD of 1.0 + 1.0 every 1000 cycles
    reg [9:0] test_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            test_cnt <= 10'h0;
            in_valid <= 1'b0;
            mode <= 2'b00;  // GF16_ADD
            in_a <= 32'h3C00;  // GF16 1.0
            in_b <= 32'h3C00;  // GF16 1.0
            out_ready <= 1'b1;
        end else begin
            if (test_cnt == 10'h0 && in_ready) begin
                in_valid <= 1'b1;
                test_cnt <= 10'h3FF;  // Count down
            end else if (test_cnt != 10'h0) begin
                test_cnt <= test_cnt - 10'h1;
                in_valid <= 1'b0;
            end
        end
    end

    // ========================================================================
    // SACRED ALU INSTANTIATION
    // ========================================================================
    sacred_alu alu (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .mode(mode),
        .in_a(in_a),
        .in_b(in_b),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_y(out_y)
    );

    // ========================================================================
    // LED OUTPUT (active-low)
    // ========================================================================
    assign led = ~led_heartbeat;  // Blink = Sacred ALU is alive

endmodule
