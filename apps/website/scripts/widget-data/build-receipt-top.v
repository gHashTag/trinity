// SPDX-License-Identifier: Apache-2.0
// build-receipt-top.v -- the hand-written board wrapper of the build-receipt widget's design.
// The datapath, StreamTernaryMac, is generated from specs/ternary/stream_ternary_mac.t27 by the
// t27 compiler (public/t27/t27_compiler.wasm); this file only ties it to the QMTech Wukong V1:
// a clock from STARTUPE2's internal CFGMCLK (no crystal pin needed), two 64-bit Fibonacci LFSRs
// as stimulus so synthesis cannot fold the MAC away, and three LEDs (pins: build-receipt.xdc).
// It is a build fixture, not a workload: nobody reads the LEDs for an answer.
`default_nettype none

module build_receipt_top (
    output wire led_d5,
    output wire led_d6,
    output wire led_j26
);
    wire cfgmclk;
    STARTUPE2 #(.PROG_USR("FALSE"), .SIM_CCLK_FREQ(10.0)) startup (
        .CFGCLK(), .CFGMCLK(cfgmclk), .EOS(), .PREQ(),
        .CLK(1'b0), .GSR(1'b0), .GTS(1'b0), .KEYCLEARB(1'b0), .PACK(1'b0),
        .USRCCLKO(1'b0), .USRCCLKTS(1'b0), .USRDONEO(1'b1), .USRDONETS(1'b1)
    );

    // x^64 + x^63 + x^61 + x^60 + 1, two different non-zero seeds.
    reg [63:0] a = 64'h0123456789ABCDEF;
    reg [63:0] b = 64'hFEDCBA9876543210;
    reg [24:0] beat = 25'd0;
    always @(posedge cfgmclk) begin
        a <= {a[62:0], a[63] ^ a[62] ^ a[60] ^ a[59]};
        b <= {b[62:0], b[63] ^ b[62] ^ b[60] ^ b[59]};
        beat <= beat + 25'd1;
    end

    wire ready;
    wire signed [31:0] acc;
    StreamTernaryMac mac (
        .clk(cfgmclk), .rst_n(1'b1), .en(1'b1),
        .a(a), .b(b), .ready(ready), .acc(acc)
    );

    assign led_d5  = ^acc;
    assign led_d6  = ready & acc[31];
    assign led_j26 = beat[24];
endmodule

`default_nettype wire
