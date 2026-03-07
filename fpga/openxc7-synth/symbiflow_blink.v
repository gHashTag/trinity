// LED blink for Symbiiflow - MUST use xc7a100t_testbench as top!
module xc7a100t_testbench (
    input  wire clk,
    output wire led
);
    reg [24:0] counter = 25'd0;
    
    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end
    
    assign led = counter[24];
endmodule
