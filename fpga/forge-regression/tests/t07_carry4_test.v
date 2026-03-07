// Test 07: CARRY4 Arithmetic
// Feature: CARRY4 for 4-bit increment
// Expected: Counter working via carry chain
module trinity_top (
    input  wire clk,
    output wire led
);
    reg [3:0] count = 4'd0;
    wire [3:0] count_next;
    wire [3:0] carry;

    // CARRY4 for increment
    CARRY4 carry_inst (
        .CI(1'b0),
        .CYINIT(1'b1),
        .DI({4'b0000}),
        .S({~count[3], ~count[2], ~count[1], ~count[0]}),
        .CO(carry),
        .O(count_next)
    );

    always @(posedge clk) begin
        count <= count_next;
    end

    assign led = count[3];
endmodule
