// TRINITY LED Controller
module trinity_led_controller (
    input wire clk, rst_n,
    input wire [1:0] pattern,
    output reg [7:0] led
);
reg [23:0] counter;
always @(posedge clk) begin
    if (!rst_n) counter<=24'd0;
    else counter<=counter+1;
end
endmodule