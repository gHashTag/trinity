//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// VSA Bind Operation on FPGA
// 16-dimensional prototype for Week 1
//
// Balanced Ternary: {-1, 0, +1}
// Bind operation: result[i] = a[i] * b[i]
//
// Truth table:
//   -1 * -1 = +1
//   -1 *  0 =  0
//   -1 * +1 = -1
//    0 *  X =  0
//   +1 * +1 = +1

module vsa_bind_16 (
    input  wire clk,
    input  wire rst,
    input  wire valid_in,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  valid_out,
    output reg  [31:0] result
);

    // Trit encoding: 2-bit signed ternary
    // 00 =  0
    // 01 = +1
    // 10 = -1

    // 16 parallel trit multipliers
    wire [1:0] t0, t1, t2, t3, t4, t5, t6, t7;
    wire [1:0] t8, t9, t10, t11, t12, t13, t14, t15;

    // Trit 0
    assign t0 = (a[1:0] == 2'b00 || b[1:0] == 2'b00) ? 2'b00 :
                (a[1:0] == 2'b01 && b[1:0] == 2'b01) ? 2'b01 :
                (a[1:0] == 2'b10 && b[1:0] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 1
    assign t1 = (a[3:2] == 2'b00 || b[3:2] == 2'b00) ? 2'b00 :
                (a[3:2] == 2'b01 && b[3:2] == 2'b01) ? 2'b01 :
                (a[3:2] == 2'b10 && b[3:2] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 2
    assign t2 = (a[5:4] == 2'b00 || b[5:4] == 2'b00) ? 2'b00 :
                (a[5:4] == 2'b01 && b[5:4] == 2'b01) ? 2'b01 :
                (a[5:4] == 2'b10 && b[5:4] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 3
    assign t3 = (a[7:6] == 2'b00 || b[7:6] == 2'b00) ? 2'b00 :
                (a[7:6] == 2'b01 && b[7:6] == 2'b01) ? 2'b01 :
                (a[7:6] == 2'b10 && b[7:6] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 4
    assign t4 = (a[9:8] == 2'b00 || b[9:8] == 2'b00) ? 2'b00 :
                (a[9:8] == 2'b01 && b[9:8] == 2'b01) ? 2'b01 :
                (a[9:8] == 2'b10 && b[9:8] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 5
    assign t5 = (a[11:10] == 2'b00 || b[11:10] == 2'b00) ? 2'b00 :
                (a[11:10] == 2'b01 && b[11:10] == 2'b01) ? 2'b01 :
                (a[11:10] == 2'b10 && b[11:10] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 6
    assign t6 = (a[13:12] == 2'b00 || b[13:12] == 2'b00) ? 2'b00 :
                (a[13:12] == 2'b01 && b[13:12] == 2'b01) ? 2'b01 :
                (a[13:12] == 2'b10 && b[13:12] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 7
    assign t7 = (a[15:14] == 2'b00 || b[15:14] == 2'b00) ? 2'b00 :
                (a[15:14] == 2'b01 && b[15:14] == 2'b01) ? 2'b01 :
                (a[15:14] == 2'b10 && b[15:14] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 8
    assign t8 = (a[17:16] == 2'b00 || b[17:16] == 2'b00) ? 2'b00 :
                (a[17:16] == 2'b01 && b[17:16] == 2'b01) ? 2'b01 :
                (a[17:16] == 2'b10 && b[17:16] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 9
    assign t9 = (a[19:18] == 2'b00 || b[19:18] == 2'b00) ? 2'b00 :
                (a[19:18] == 2'b01 && b[19:18] == 2'b01) ? 2'b01 :
                (a[19:18] == 2'b10 && b[19:18] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 10
    assign t10 = (a[21:20] == 2'b00 || b[21:20] == 2'b00) ? 2'b00 :
                 (a[21:20] == 2'b01 && b[21:20] == 2'b01) ? 2'b01 :
                 (a[21:20] == 2'b10 && b[21:20] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 11
    assign t11 = (a[23:22] == 2'b00 || b[23:22] == 2'b00) ? 2'b00 :
                 (a[23:22] == 2'b01 && b[23:22] == 2'b01) ? 2'b01 :
                 (a[23:22] == 2'b10 && b[23:22] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 12
    assign t12 = (a[25:24] == 2'b00 || b[25:24] == 2'b00) ? 2'b00 :
                 (a[25:24] == 2'b01 && b[25:24] == 2'b01) ? 2'b01 :
                 (a[25:24] == 2'b10 && b[25:24] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 13
    assign t13 = (a[27:26] == 2'b00 || b[27:26] == 2'b00) ? 2'b00 :
                 (a[27:26] == 2'b01 && b[27:26] == 2'b01) ? 2'b01 :
                 (a[27:26] == 2'b10 && b[27:26] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 14
    assign t14 = (a[29:28] == 2'b00 || b[29:28] == 2'b00) ? 2'b00 :
                 (a[29:28] == 2'b01 && b[29:28] == 2'b01) ? 2'b01 :
                 (a[29:28] == 2'b10 && b[29:28] == 2'b10) ? 2'b01 : 2'b10;

    // Trit 15
    assign t15 = (a[31:30] == 2'b00 || b[31:30] == 2'b00) ? 2'b00 :
                 (a[31:30] == 2'b01 && b[31:30] == 2'b01) ? 2'b01 :
                 (a[31:30] == 2'b10 && b[31:30] == 2'b10) ? 2'b01 : 2'b10;

    // Pipeline register
    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 0;
            result <= 32'd0;
        end else begin
            valid_out <= valid_in;
            result <= {t15, t14, t13, t12, t11, t10, t9, t8,
                       t7, t6, t5, t4, t3, t2, t1, t0};
        end
    end

endmodule

// Top module for testing
module vsa_bind_16_top (
    input  wire clk,
    input  wire rst,
    output wire led
);

    // LFSR for generating test vectors
    reg [31:0] lfsr;
    reg [23:0] blink_counter;
    reg led_reg;

    always @(posedge clk) begin
        if (rst) begin
            lfsr <= 32'h1370000;
        end else begin
            lfsr <= (lfsr << 1) ^ ((lfsr & 32'h80000000) ? 32'h80200003 : 32'd0);
        end
    end

    // Extract vectors from LFSR
    wire [31:0] vector_a;
    wire [31:0] vector_b;

    genvar k;
    generate
        for (k = 0; k < 16; k = k + 1) begin : trit_extract
            wire [1:0] trit_a;
            wire [1:0] trit_b;

            assign trit_a = (lfsr[k] == lfsr[k+16]) ? 2'b00 :
                           (lfsr[k] == 1'b1) ? 2'b01 : 2'b10;

            assign trit_b = (lfsr[(k+1) % 16] == lfsr[(k+1+16) % 32]) ? 2'b00 :
                           (lfsr[(k+1) % 16] == 1'b1) ? 2'b01 : 2'b10;

            assign vector_a[2*k +: 2] = trit_a;
            assign vector_b[2*k +: 2] = trit_b;
        end
    endgenerate

    // VSA bind
    wire valid_out;
    wire [31:0] bind_result;

    vsa_bind_16 bind_unit (
        .clk(clk),
        .rst(rst),
        .valid_in(1'b1),
        .a(vector_a),
        .b(vector_b),
        .valid_out(valid_out),
        .result(bind_result)
    );

    // Count non-zero trits
    function [4:0] count_non_zero;
        input [31:0] v;
        begin
            count_non_zero = 0;
            if (v[1:0] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[3:2] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[5:4] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[7:6] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[9:8] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[11:10] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[13:12] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[15:14] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[17:16] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[19:18] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[21:20] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[23:22] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[25:24] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[27:26] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[29:28] != 2'b00) count_non_zero = count_non_zero + 1;
            if (v[31:30] != 2'b00) count_non_zero = count_non_zero + 1;
        end
    endfunction

    // LED blink based on result
    wire [4:0] non_zero_count = count_non_zero(bind_result);

    always @(posedge clk) begin
        blink_counter <= blink_counter + 1;

        if (non_zero_count > 8) begin
            if (blink_counter[20] == 1) led_reg <= ~led_reg;
        end else if (non_zero_count > 4) begin
            if (blink_counter[22] == 1) led_reg <= ~led_reg;
        end else begin
            if (blink_counter[23] == 1) led_reg <= ~led_reg;
        end
    end

    assign led = ~led_reg;

endmodule
