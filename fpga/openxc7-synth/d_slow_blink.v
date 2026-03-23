//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// D21 LED slow blink (1 Hz for testing)
module trinity_top (
    input  wire clk,
    output wire led
);
    reg [23:0] counter = 24'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    // Very slow blink: 50MHz / 2^23 = 6 Hz
    assign led = counter[23];  // NO inversion for testing
endmodule
