`default_nettype none

// DYNAMIC TERNARY DOT PRODUCT — FORGE OF KOSCHEI v2.0
// 16-trit dot product with LFSR-generated dynamic inputs
// Proves REAL ternary {-1, 0, +1} computation on silicon
//
// Trit encoding: 2 bits per trit
//   00 = -1, 01 = 0, 10 = +1, 11 = reserved (treated as 0)
//
// Architecture:
//   LFSR (32-bit) generates pseudo-random bit stream every clock
//   Every ~0.67 seconds (2^25 clocks @ 50MHz), we sample 32 LFSR bits
//   as 16 dynamic trits, compute dot product against fixed weights,
//   and display sign on LED:
//     LED blinks fast  = dot > 0
//     LED off          = dot == 0
//     LED on solid     = dot < 0
//
// phi^2 + 1/phi^2 = 3 = TRINITY

module ternary_dot_top (
    input  wire clk,
    output wire led
);

    // === 32-bit LFSR (maximal length, taps at 32,22,2,1) ===
    // Generates pseudo-random stream, period = 2^32 - 1
    reg [31:0] lfsr = 32'hDEAD_BEEF;  // non-zero seed
    wire lfsr_feedback = lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0];

    always @(posedge clk)
        lfsr <= {lfsr[30:0], lfsr_feedback};

    // === SLOW TIMER: sample every ~0.67s ===
    reg [25:0] timer = 0;
    wire sample_tick = (timer == 0);

    always @(posedge clk)
        timer <= timer + 1'b1;

    // === DYNAMIC INPUT REGISTER: latch 32 LFSR bits as 16 trits ===
    reg [31:0] input_trits = 32'hAAAA_AAAA; // initial: all +1

    always @(posedge clk)
        if (sample_tick)
            input_trits <= lfsr;

    // === FIXED WEIGHTS (16 trits) ===
    // {+1,-1,+1,+1, 0,+1,-1,+1, +1,+1,0,-1, +1,-1,+1,+1}
    localparam [31:0] WEIGHTS = {
        2'b10, 2'b10, 2'b00, 2'b10,   // trits 15-12: +1,+1,-1,+1
        2'b00, 2'b01, 2'b10, 2'b10,   // trits 11-8:  -1, 0,+1,+1
        2'b10, 2'b00, 2'b10, 2'b01,   // trits 7-4:   +1,-1,+1, 0
        2'b10, 2'b10, 2'b00, 2'b10    // trits 3-0:   +1,+1,-1,+1
    };

    // === TRIT SANITIZE + MULTIPLY ===
    // Sanitize: encoding 11 (reserved) maps to 0
    // Multiply: {-1,0,+1} x {-1,0,+1} -> {-1,0,+1}
    wire signed [1:0] prod [0:15];

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : trit_mac
            wire [1:0] w = WEIGHTS[i*2+1 : i*2];
            wire [1:0] x_raw = input_trits[i*2+1 : i*2];

            // Sanitize: treat 11 as 0 (01)
            wire [1:0] x = (x_raw == 2'b11) ? 2'b01 : x_raw;

            // Decode trits to signed values
            wire w_neg  = (w == 2'b00);
            wire w_zero = (w == 2'b01);
            wire w_pos  = (w == 2'b10);
            wire x_neg  = (x == 2'b00);
            wire x_zero = (x == 2'b01);
            wire x_pos  = (x == 2'b10);

            // Ternary multiply: only add/sub, no actual multiplier
            wire res_neg  = (w_neg & x_pos) | (w_pos & x_neg);
            wire res_zero = w_zero | x_zero;
            wire res_pos  = (w_neg & x_neg) | (w_pos & x_pos);

            assign prod[i] = res_zero ? 2'sb00 :
                              res_neg  ? -2'sb01 :
                                          2'sb01;
        end
    endgenerate

    // === ADDER TREE: sum 16 signed products ===
    // Level 1: 8 sums (3-bit signed)
    wire signed [2:0] sum_l1 [0:7];
    generate
        for (i = 0; i < 8; i = i + 1) begin : add_l1
            assign sum_l1[i] = prod[i*2] + prod[i*2+1];
        end
    endgenerate

    // Level 2: 4 sums (4-bit signed)
    wire signed [3:0] sum_l2 [0:3];
    generate
        for (i = 0; i < 4; i = i + 1) begin : add_l2
            assign sum_l2[i] = sum_l1[i*2] + sum_l1[i*2+1];
        end
    endgenerate

    // Level 3: 2 sums (5-bit signed)
    wire signed [4:0] sum_l3 [0:1];
    generate
        for (i = 0; i < 2; i = i + 1) begin : add_l3
            assign sum_l3[i] = sum_l2[i*2] + sum_l2[i*2+1];
        end
    endgenerate

    // Final: 6-bit signed, range [-16, +16]
    wire signed [5:0] dot_result = sum_l3[0] + sum_l3[1];

    // === RESULT REGISTER: latch dot product ===
    reg signed [5:0] dot_latched = 0;
    always @(posedge clk)
        if (sample_tick)
            dot_latched <= dot_result;

    // === LED OUTPUT ===
    // Blink counter for visible feedback
    reg [22:0] blink_cnt = 0;
    always @(posedge clk)
        blink_cnt <= blink_cnt + 1'b1;

    // LED behavior:
    //   dot > 0: fast blink (~3 Hz)
    //   dot == 0: slow blink (~0.75 Hz)
    //   dot < 0: LED solid on
    wire dot_pos = (dot_latched > 0);
    wire dot_neg = (dot_latched < 0);
    wire dot_zero = (dot_latched == 0);

    assign led = dot_neg  ? 1'b0 :           // solid ON (active low)
                 dot_zero ? ~blink_cnt[22] :  // slow blink
                            ~blink_cnt[21];   // fast blink

endmodule
