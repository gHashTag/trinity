// ============================================================================
// JTAG Echo — BSCANE2-based communication via JTAG cable
// ============================================================================
// No external UART pins needed! Data flows through the JTAG cable itself.
//
// Host sends 8-bit data via USER1 DR scan → FPGA echoes it back
// LED D5 blinks as heartbeat, LED D6 toggles on each received byte
//
// Protocol:
//   1. IR scan: USER1 (0x02, 6-bit)
//   2. DR scan: shift in 8 bits → get back previous 8 bits
// ============================================================================

`timescale 1ns / 1ps
`default_nettype none

module jtag_echo_top (
    input  wire clk,
    output wire led_d5,   // Heartbeat
    output wire led_d6    // RX activity
);

    // ========================================================================
    // BSCANE2 — connects to internal JTAG TAP, USER1 instruction
    // ========================================================================
    wire bscan_capture;
    wire bscan_drck;
    wire bscan_reset;
    wire bscan_runtest;
    wire bscan_sel;
    wire bscan_shift;
    wire bscan_tck;
    wire bscan_tdi;
    wire bscan_tms;
    wire bscan_update;
    wire bscan_tdo;

    BSCANE2 #(
        .JTAG_CHAIN(1)  // USER1
    ) bscan_inst (
        .CAPTURE (bscan_capture),
        .DRCK    (bscan_drck),
        .RESET   (bscan_reset),
        .RUNTEST (bscan_runtest),
        .SEL     (bscan_sel),
        .SHIFT   (bscan_shift),
        .TCK     (bscan_tck),
        .TDI     (bscan_tdi),
        .TMS     (bscan_tms),
        .UPDATE  (bscan_update),
        .TDO     (bscan_tdo)
    );

    // ========================================================================
    // 8-bit shift register — simple loopback
    // ========================================================================
    // DRCK pulses during both Capture-DR and Shift-DR.
    // SHIFT is high only during Shift-DR state.
    // Strategy: just use TCK + SHIFT for shifting, CAPTURE to load echo.
    reg [7:0] shift_reg;
    reg [7:0] latch_reg;  // Latched on UPDATE
    reg rx_toggle;

    // Use TCK (continuous JTAG clock when selected)
    always @(posedge bscan_tck) begin
        if (bscan_sel) begin
            if (bscan_capture) begin
                // Load previously latched value for readback
                shift_reg <= latch_reg;
            end else if (bscan_shift) begin
                // Shift: TDI in at MSB, TDO out from LSB
                shift_reg <= {bscan_tdi, shift_reg[7:1]};
            end
        end
    end

    // Latch on UPDATE (after Shift-DR completes)
    always @(posedge bscan_tck) begin
        if (bscan_sel && bscan_update) begin
            latch_reg <= shift_reg;
            rx_toggle <= ~rx_toggle;
        end
    end

    assign bscan_tdo = shift_reg[0];

    // ========================================================================
    // LED heartbeat (clk domain)
    // ========================================================================
    reg [24:0] hb_counter;
    always @(posedge clk) begin
        hb_counter <= hb_counter + 1;
    end

    // Active-low LEDs on QMTech
    assign led_d5 = ~hb_counter[24];  // Heartbeat ~1.5 Hz
    assign led_d6 = ~rx_toggle;        // Toggle on each byte received

endmodule
