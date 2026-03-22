// LED blink - top module name is trinity_top
module trinity_top (
    input  wire clk,
    output wire led
);
    reg [24:0] counter = 25'd0;
    
    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end
    
    assign led = ~counter[24];  // Active-low
endmodule
