// Test 02: Direct Clock
// Feature: Clock directly to LED (no FF)
// Expected: 50 MHz clock signal (LED may appear dim)
module trinity_top (
    input  wire clk,
    output wire led
);
    // Direct clock connection
    assign led = clk;
endmodule
