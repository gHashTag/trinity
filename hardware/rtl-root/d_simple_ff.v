// Simple FF test (no counter, no carry chain)
module trinity_top (
    input  wire clk,
    output wire led
);
    wire clk_bufged;
    reg q = 0;
    
    BUFG clk_buf (.I(clk), .O(clk_bufged));
    
    // Single FF: toggle every clock
    always @(posedge clk_bufged) begin
        q <= ~q;
    end
    
    assign led = ~q;  // Active-low
endmodule
