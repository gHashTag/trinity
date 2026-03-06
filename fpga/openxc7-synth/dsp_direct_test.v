`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════════
// DSP48E1 DIRECT TEST — Simple multiplier test
// ═══════════════════════════════════════════════════════════════════════════════
//
// Direct test of DSP48E1 multiplier
// Connects inputs to switches, outputs to LEDs
//
// Expected: 3 DSP48E1 cells in synthesis

module dsp_direct_test (
    input  wire       clk,
    input  wire       rst,
    input  wire [31:0] sw,    // Switches for A and B
    input  wire       valid,  // Valid signal
    output wire [31:0] led,   // Result output
    output wire       busy    // Busy indicator
);

    // Instantiate DSP multiplier
    dsp_mul32 multiplier (
        .clk(clk),
        .rst_n(~rst),      // Invert reset (active high)
        .valid_in(valid),
        .a(sw[31:16]),     // Upper switches = A
        .b(sw[15:0]),      // Lower switches = B
        .result(led),
        .valid_out(busy)
    );

endmodule
