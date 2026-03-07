// Test with Y0 sub-pin (instead of Y1)
module trinity_top (
    input  wire clk,
    output wire led
);
    wire clk_bufged;
    
    BUFG clk_buf (.I(clk), .O(clk_bufged));
    
    reg [23:0] counter = 24'd0;
    always @(posedge clk_bufged) begin
        counter <= counter + 1'b1;
    end
    
    assign led = counter[23];
endmodule
