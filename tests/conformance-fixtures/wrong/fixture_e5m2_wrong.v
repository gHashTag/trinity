// FP8 E5M2 with ONE planted defect: subnormals flushed to zero. -> FP32 decode. 1 sign + 5 exponent (bias 15) + 2 mantissa,
// with Inf and NaN, per IEEE-style / OCP MX.
//
// Used by the conformance self-test as the case that must be CAUGHT.
// A gate nobody has watched go red is not a gate.
//
`default_nettype none

module fixture_e5m2_wrong (
    input  wire [7:0]  e5m2_in,
    output reg  [31:0] fp32_out
);
    wire       sign = e5m2_in[7];
    wire [4:0] exp  = e5m2_in[6:2];
    wire [1:0] mant = e5m2_in[1:0];

    wire is_zero = (exp == 5'd0)    && (mant == 2'd0);
    wire is_inf  = (exp == 5'h1F)   && (mant == 2'd0);
    wire is_nan  = (exp == 5'h1F)   && (mant != 2'd0);

    reg [7:0]  e32;
    reg [22:0] m32;

    always @(*) begin
        if (is_inf)            begin e32 = 8'hFF; m32 = 23'h000000; end
        else if (is_nan)       begin e32 = 8'hFF; m32 = 23'h400000; end
        else if (is_zero)      begin e32 = 8'h00; m32 = 23'h000000; end
        else if (exp == 5'd0) begin
            // THE PLANTED DEFECT: subnormals flushed to zero. Six of the 256
            // code points -- three mantissas, two signs -- and nothing else in
            // the format is touched. Chosen because it is the defect a decoder
            // actually gets wrong, and because a checker that only looks at
            // normals will not notice it.
            e32 = 8'h00; m32 = 23'h000000;
        end else begin
            e32 = {3'b0, exp} + 8'd112;
            m32 = {mant, 21'b0};
        end
        fp32_out = {sign, e32, m32};
    end
endmodule
