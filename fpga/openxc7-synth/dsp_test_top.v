//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY CORE DSP TEST TOP
// ═══════════════════════════════════════════════════════════════════════════════
//
// Test module to verify DSP48E1 inference
// Instantiates trinity_core with USE_DSP=1
//
// Expected synthesis results:
// - 4+ DSP48E1 slices used
// - LUT count reduced compared to LUT-only version
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

module dsp_test_top (
    input  wire       clk,
    input  wire       rst_n,
    output wire       uart_tx,
    input  wire       uart_rx,
    output wire [3:0] led,
    output wire       running,
    output wire [11:0] pc
);

    // TRINITY CORE with DSP-enabled multiplier
    trinity_core #(
        .BOOT_ADDR(12'h000),
        .PC_WIDTH(12),
        .USE_DSP(1)          // Enable DSP48E1
    ) core (
        .clk(clk),
        .rst_n(rst_n),
        .instr_addr(),       // BRAM interface (tied to internal)
        .instr_data(32'd0),  // For test, tie to 0
        .data_we(),
        .data_addr(),
        .data_wdata(),
        .data_rdata(32'd0),
        .gpio_out(led),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .running(running),
        .pc(pc)
    );

endmodule
