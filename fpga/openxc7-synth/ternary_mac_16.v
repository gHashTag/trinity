// Ternary MAC Cell — Dot Product Unit (BENCH-006)
// Computes: y += w·x for 16-dimensional vectors
// w[i], x[i] ∈ {-1, 0, +1} (ternary, 2-bit encoding)
// Result: y ∈ {-16, -15, ..., +15, +16} (5-bit signed)

`default_nettype none

module ternary_mac_16 (
    input  wire clk,
    input  wire rst_n,
    input  wire [31:0] w,    // 16 × 2-bit ternary weights [00=-1, 01=0, 10=+1]
    input  wire [31:0] x,    // 16 × 2-bit ternary inputs [00=-1, 01=0, 10=+1]
    output wire [4:0] y,     // Accumulator output (5-bit signed)
    output wire led          // Status LED (T23, active-low)
);

    // ========================================================================
    // INPUT REGISTERS (for fair Fmax measurement)
    // ========================================================================
    reg [31:0] w_reg;
    reg [31:0] x_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_reg <= 32'h0;
            x_reg <= 32'h0;
        end else begin
            w_reg <= w;
            x_reg <= x;
        end
    end

    // ========================================================================
    // TERNARY MAC: y += w[i] · x[i]
    // ========================================================================
    // Ternary multiply: w·x ∈ {-1, 0, +1} → XOR-based
    // Encoding: 00=-1, 01=0, 10=+1 (unused: 11)

    // Generate partial products (16 terms)
    wire signed [4:0] pp [16];
    genvar i;
    generate for (i = 0; i < 16; i = i + 1) begin : gen_pp
        wire [1:0] w_bits = w_reg[2*i +: 2];
        wire [1:0] x_bits = x_reg[2*i +: 2];

        // Ternary multiply via XOR (negate if signs differ)
        wire w_is_neg = (w_bits == 2'b00);
        wire x_is_neg = (x_bits == 2'b00);
        wire w_is_pos = (w_bits == 2'b10);
        wire x_is_pos = (x_bits == 2'b10);
        wire w_is_zero = (w_bits == 2'b01);
        wire x_is_zero = (x_bits == 2'b01);

        // w·x result: 0 if either is zero, XOR of signs
        wire mul_is_zero = w_is_zero | x_is_zero;
        wire mul_is_neg = w_is_neg ^ x_is_neg;  // XOR: negative if signs differ
        wire mul_is_pos = w_is_pos & x_is_pos;  // AND: positive if both positive

        // Partial product value
        assign pp[i] = mul_is_zero ? 5'd0 :
                       mul_is_neg ? 5'd16 :  // -1 in 5-bit
                       5'd1;            // +1
    end
    endgenerate

    // Accumulate partial products (add tree)
    wire signed [4:0] acc_stage0 = pp[0] + pp[1];
    wire signed [4:0] acc_stage1 = acc_stage0 + pp[2];
    wire signed [4:0] acc_stage2 = acc_stage1 + pp[3];
    wire signed [4:0] acc_stage3 = acc_stage2 + pp[4];
    wire signed [4:0] acc_stage4 = acc_stage3 + pp[5];
    wire signed [4:0] acc_stage5 = acc_stage4 + pp[6];
    wire signed [4:0] acc_stage6 = acc_stage5 + pp[7];
    wire signed [4:0] acc_stage7 = acc_stage6 + pp[8];
    wire signed [4:0] acc_stage8 = acc_stage7 + pp[9];
    wire signed [4:0] acc_stage9 = acc_stage8 + pp[10];
    wire signed [4:0] acc_stage10 = acc_stage9 + pp[11];
    wire signed [4:0] acc_stage11 = acc_stage10 + pp[12];
    wire signed [4:0] acc_stage12 = acc_stage11 + pp[13];
    wire signed [4:0] acc_stage13 = acc_stage12 + pp[14];
    wire signed [4:0] acc_stage14 = acc_stage13 + pp[15];

    // ========================================================================
    // OUTPUT REGISTER (for fair Fmax measurement)
    // ========================================================================
    reg [4:0] y_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_reg <= 5'd0;
        end else begin
            y_reg <= acc_stage14;
        end
    end

    assign y = y_reg;

    // ========================================================================
    // STATUS LED — T23 (active-low, D6)
    // ========================================================================
    assign led = rst_n ? 1'b0 : 1'b1;  // ON when not reset

endmodule
