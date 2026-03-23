//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// LED BLINK TEST v2 — Uses POR (proven pattern) + slow blink
// =============================================================================
// Blinks D6 (T23) at ~0.37 Hz (2.7s period) — VERY obvious to human eye.
// Uses the same POR pattern as all our working designs.
// Active-low LED: 0=ON, 1=OFF
// =============================================================================

`timescale 1ns / 1ps

module led_blink_test (
    input  wire clk,       // 50 MHz, U22
    output wire led,       // Active-low, T23 (D6)
    output wire [1:0] debug_state  // N23, M22
);

    // =====================================================================
    // INTERNAL POWER-ON RESET (255 clock cycles) — proven pattern
    // =====================================================================
    reg [7:0] por_counter = 8'd0;
    reg       rst = 1'b1;

    always @(posedge clk) begin
        if (por_counter < 8'd255) begin
            por_counter <= por_counter + 1;
            rst <= 1'b1;
        end else begin
            rst <= 1'b0;
        end
    end

    // =====================================================================
    // BLINK COUNTER — 26-bit, toggles at ~0.37 Hz
    // =====================================================================
    reg [25:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            counter <= 26'd0;
        end else begin
            counter <= counter + 1;
        end
    end

    // Active-low: counter[25] = 1 → led = 0 (ON)
    //             counter[25] = 0 → led = 1 (OFF)
    assign led = ~counter[25];

    // Debug: state[0] = blink running (not reset), state[1] = counter MSB
    assign debug_state[0] = ~rst;
    assign debug_state[1] = counter[25];

endmodule
