// Clean FP8 E5M2 -> FP32 decode. 1 sign + 5 exponent (bias 15) + 2 mantissa,
// with Inf and NaN, per IEEE-style / OCP MX.
//
// Used by the conformance self-test as the case that must pass exhaustively.
// It is checked against ml_dtypes.float8_e5m2 over all 256 code points, so
// "clean" here is measured rather than asserted.
`default_nettype none

module fixture_e5m2 (
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
            // Subnormal: 2^-14 * 0.mant, normalised into fp32.
            if (mant[1]) begin e32 = 8'd112; m32 = {mant[0], 22'b0}; end
            else         begin e32 = 8'd111; m32 = 23'b0;            end
        end else begin
            e32 = {3'b0, exp} + 8'd112;
            m32 = {mant, 21'b0};
        end
        fp32_out = {sign, e32, m32};
    end
endmodule
