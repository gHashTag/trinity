// Using STARTUPE2 internal oscillator
module trinity_top (
    input  wire clk,   // Not used!
    output wire led
);
    // Internal clock via STARTUPE2
    wire clk_int;
    reg [23:0] counter = 24'd0;
    
    // Try to use internal configuration clock
    // CCLK is available during configuration but may not run after
    
    // Even simpler: just toggle on a slow LUT chain
    reg [3:0] slow_chain = 4'b0000;
    
    // Combinatorial "toggle" using LUT cascade
    wire [3:0] next_chain;
    assign next_chain[0] = ~slow_chain[0];
    assign next_chain[1] = slow_chain[0] ^ slow_chain[1];
    assign next_chain[2] = slow_chain[1] ^ slow_chain[2];
    assign next_chain[3] = slow_chain[2] ^ slow_chain[3];
    
    // Try to make it oscillate combinatorially
    assign led = next_chain[0];
endmodule
