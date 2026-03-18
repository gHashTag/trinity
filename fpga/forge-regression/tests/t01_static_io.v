// Test 01: Static IO
// Feature: Static output (OBUF only)
// Expected: LED ON constantly
module trinity_top (
    input  wire clk,
    output wire led
);
    // Static 1 (LED ON)
    assign led = 1'b1;
endmodule
