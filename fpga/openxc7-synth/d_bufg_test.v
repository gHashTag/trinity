// Explicit BUFG test
module trinity_top (
    input  wire clk,
    output wire led
);
    wire clk_bufged;
    
    // Explicit BUFG instantiation
    BUFG clk_buf (
        .I(clk),
        .O(clk_bufged)
    );
    
    // Simple counter with buffered clock
    reg [23:0] counter = 24'd0;
    always @(posedge clk_bufged) begin
        counter <= counter + 1'b1;
    end
    
    assign led = counter[23];
endmodule
