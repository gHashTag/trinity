//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// Slow blink on T23 (active-low)
module trinity_top (
    input  wire clk,
    output wire led
);
    reg [23:0] counter = 24'd0;
    
    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end
    
    assign led = ~counter[23];  // Active-low, slower (~6 Hz)
endmodule
