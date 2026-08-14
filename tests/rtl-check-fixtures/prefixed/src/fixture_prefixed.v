// Clean: every branch assigns, so nothing has to hold, and it is sequential.
module fixture_prefixed (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    input  wire [3:0] d,
    output reg  [3:0] q
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)   q <= 4'd0;
        else if (en)  q <= d;
        else          q <= q;
    end
endmodule
