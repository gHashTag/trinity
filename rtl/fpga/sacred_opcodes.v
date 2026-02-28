// TRINITY Sacred Opcodes
module trinity_sacred_opcodes (
    input wire clk,
    input wire [7:0] opcode,
    output reg [31:0] data_out,
    output reg valid
);
localparam PHI_Q16=32'h1_9E37, PI_Q16=32'h3_243F, E_Q16=32'h2_B7E1;
always @(posedge clk) begin
    valid<=1'b0;
    case(opcode)
        8'h80: begin data_out<=PHI_Q16; valid<=1'b1; end
        8'h81: begin data_out<=PI_Q16; valid<=1'b1; end
        8'h82: begin data_out<=E_Q16; valid<=1'b1; end
    endcase
end
endmodule