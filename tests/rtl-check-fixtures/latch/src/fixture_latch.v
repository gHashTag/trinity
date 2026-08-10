// One planted defect: a combinational block with no else, so q must hold its
// value and synthesis infers a level-sensitive latch. The classic bug the latch
// check exists for, and the only thing wrong with this file.
module fixture_latch (
    input  wire       en,
    input  wire [3:0] d,
    output reg  [3:0] q
);
    always @(*) begin
        if (en) q = d;
    end
endmodule
