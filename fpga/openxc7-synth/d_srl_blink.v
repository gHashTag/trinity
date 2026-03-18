// SRL16E-based blink (no FD flip-flops)
module trinity_top (
    input  wire clk,
    output wire led
);
    // 16-bit LUT shift register for slow divide
    // SRL16E: 16-bit shift register with clock enable
    reg [15:0] shift = 16'h0001;
    
    always @(posedge clk) begin
        // Rotate through 16 bits
        shift <= {shift[14:0], shift[15]};
    end
    
    // Active-low LED
    assign led = ~shift[15];
endmodule
