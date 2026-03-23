//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ═══════════════════════════════════════════════════════════════════════════════
// VSA Multi-Operation Pipeline — KOSCHEI Week 3
// ═══════════════════════════════════════════════════════════════════════════════
//
// Full VSA pipeline in hardware: Bind → Bundle → Similarity
// Target: < 50 ns total latency (2-3 cycles @ 50MHz)
//
// Architecture:
//   Stage 1: Bind (256 parallel trit multipliers)
//   Stage 2: Bundle (256-input majority vote)
//   Stage 3: Similarity (cosine computation)
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE 1: BIND OPERATION
// ═══════════════════════════════════════════════════════════════════════════════

module vsa_bind_stage (
    input  wire clk,
    input  wire rst,
    input  wire valid_in,
    input  wire [511:0] a,      // 256 trits × 2 bits
    input  wire [511:0] b,      // 256 trits × 2 bits
    output reg  valid_out,
    output reg  [511:0] result  // Bound vector
);

    // Trit encoding: 2-bit signed ternary
    // 00 =  0
    // 01 = +1
    // 10 = -1

    // 256 parallel trit multipliers
    wire [1:0] trit_result [255:0];

    genvar i;
    generate
        for (i = 0; i < 256; i = i + 1) begin : trit_mult
            wire [1:0] a_trit = a[2*i +: 2];
            wire [1:0] b_trit = b[2*i +: 2];

            // Trit multiplication: optimized for LUT5
            // Truth table: (a == 0 || b == 0) ? 0 : (a == b) ? +1 : -1
            assign trit_result[i] =
                (a_trit == 2'b00 || b_trit == 2'b00) ? 2'b00 :
                (a_trit == b_trit) ? 2'b01 : 2'b10;
        end
    endgenerate

    // Pipeline register
    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 0;
            result <= 512'd0;
        end else begin
            valid_out <= valid_in;

            // Pack 256 trit results (optimized unroll)
            for (i = 0; i < 256; i = i + 1) begin
                result[2*i +: 2] <= trit_result[i];
            end
        end
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE 2: BUNDLE OPERATION (Majority Vote)
// ═══════════════════════════════════════════════════════════════════════════════

module vsa_bundle_stage (
    input  wire clk,
    input  wire rst,
    input  wire valid_in,
    input  wire [511:0] vectors [2:0],  // Up to 3 vectors to bundle
    input  wire [1:0] num_vectors,       // 2, 3, or 4 (including result)
    output reg  valid_out,
    output reg  [511:0] result
);

    // Bundle via majority vote
    // For each trit position: count +1, -1, 0, then take majority

    wire [1:0] trit_result [255:0];

    genvar i;
    generate
        for (i = 0; i < 256; i = i + 1) begin : trit_bundle
            // Extract trits from each input vector
            wire [1:0] t0 = vectors[0][2*i +: 2];
            wire [1:0] t1 = vectors[1][2*i +: 2];
            wire [1:0] t2 = vectors[2][2*i +: 2];

            // Count votes
            wire [2:0] pos_votes = (t0 == 2'b01) + (t1 == 2'b01) + (t2 == 2'b01);
            wire [2:0] neg_votes = (t0 == 2'b10) + (t1 == 2'b10) + (t2 == 2'b10);
            wire [2:0] zero_votes = (t0 == 2'b00) + (t1 == 2'b00) + (t2 == 2'b00);

            // Majority logic
            assign trit_result[i] =
                (pos_votes >= 2) ? 2'b01 :      // Positive majority
                (neg_votes >= 2) ? 2'b10 :      // Negative majority
                2'b00;                          // Zero (tie or majority)
        end
    endgenerate

    // Pipeline register
    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 0;
            result <= 512'd0;
        end else begin
            valid_out <= valid_in;

            // Pack results
            for (i = 0; i < 256; i = i + 1) begin
                result[2*i +: 2] <= trit_result[i];
            end
        end
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE 3: SIMILARITY (Cosine for Ternary Vectors)
// ═══════════════════════════════════════════════════════════════════════════════

module vsa_similarity_stage (
    input  wire clk,
    input  wire rst,
    input  wire valid_in,
    input  wire [511:0] a,
    input  wire [511:0] b,
    output reg  valid_out,
    output reg  [15:0] similarity  // Scaled 0-10000 (0.0000 to 1.0000)
);

    // Cosine similarity for ternary vectors:
    // sim = (a · b) / (||a|| * ||b||)
    // For trits {-1,0,+1}: dot = count(agreed) - count(disagreed)

    // Count matches in parallel (256 trits)
    wire [8:0] agreed;   // 0 to 256
    wire [8:0] disagreed;

    // Parallel count generation
    genvar i;
    wire [255:0] agree_bits;
    wire [255:0] disagree_bits;

    generate
        for (i = 0; i < 256; i = i + 1) begin : check_trit
            wire [1:0] ta = a[2*i +: 2];
            wire [1:0] tb = b[2*i +: 2];

            // Agree: both same non-zero value
            assign agree_bits[i] = (ta != 2'b00) && (tb != 2'b00) && (ta == tb);

            // Disagree: different non-zero values
            assign disagree_bits[i] = (ta != 2'b00) && (tb != 2'b00) && (ta != tb);
        end
    endgenerate

    // Count bits (population count)
    assign agreed = count_ones(agree_bits);
    assign disagreed = count_ones(disagree_bits);

    // Population count function (optimized for 256 bits)
    function [8:0] count_ones;
        input [255:0] bits;
        begin
            count_ones = 0;
            for (i = 0; i < 256; i = i + 1) begin
                count_ones = count_ones + bits[i];
            end
        end
    endfunction

    // Calculate similarity (simplified for ternary)
    // sim = (agreed - disagreed) / (agreed + disagreed)
    // Scale to 0-10000 range
    wire [16:0] dot_prod = $signed(agreed) - $signed(disagreed);  // -256 to +256
    wire [16:0] mag_sum = agreed + disagreed;                       // 0 to 256

    // Similarity with saturation
    wire [15:0] sim_scaled;
    assign sim_scaled = (mag_sum == 0) ? 16'd5000 :  // Neutral if both zero
                        ((dot_prod >= 0) ?
                            ((dot_prod << 8) / mag_sum) :     // Positive similarity
                            (({dot_prod[16], dot_prod} << 8) / mag_sum));  // Negative (rare)

    // Pipeline register
    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 0;
            similarity <= 16'd0;
        end else begin
            valid_out <= valid_in;
            similarity <= sim_scaled;
        end
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// FULL VSA PIPELINE TOP MODULE
// ═══════════════════════════════════════════════════════════════════════════════

module vsa_pipeline_256 (
    input  wire clk,
    input  wire rst,
    input  wire valid_in,

    // Bind inputs
    input  wire [511:0] bind_a,
    input  wire [511:0] bind_b,

    // Bundle inputs (optional)
    input  wire [511:0] bundle_c,
    input  wire bundle_enable,

    // Similarity compare (optional)
    input  wire [511:0] sim_ref,
    input  wire sim_enable,

    // Operation select
    input  wire [1:0] op,  // 00=bind, 01=bundle, 10=similarity, 11=full_pipeline

    // Outputs
    output reg  valid_out,
    output wire [511:0] bind_result,
    output wire [511:0] bundle_result,
    output wire [15:0] similarity_score
);

    // Stage 1: Bind
    wire bind_valid;
    wire [511:0] bound;

    vsa_bind_stage bind_stage (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .a(bind_a),
        .b(bind_b),
        .valid_out(bind_valid),
        .result(bound)
    );

    // Stage 2: Bundle (if enabled)
    wire bundle_valid;
    wire [511:0] bundled;

    vsa_bundle_stage bundle_stage (
        .clk(clk),
        .rst(rst),
        .valid_in(bind_valid && bundle_enable),
        .vectors('{bound, bind_a, bundle_c}),  // Use bound + original inputs
        .num_vectors(2'b11),
        .valid_out(bundle_valid),
        .result(bundled)
    );

    // Stage 3: Similarity (if enabled)
    wire sim_valid;
    wire [15:0] sim;

    vsa_similarity_stage sim_stage (
        .clk(clk),
        .rst(rst),
        .valid_in(bundle_valid && sim_enable),
        .a(bundled),
        .b(sim_ref),
        .valid_out(sim_valid),
        .similarity(sim)
    );

    // Output multiplexing based on operation
    reg [511:0] bind_result_reg;
    reg [511:0] bundle_result_reg;

    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 0;
            bind_result_reg <= 0;
            bundle_result_reg <= 0;
        end else begin
            case (op)
                2'b00: begin  // Bind only
                    bind_result_reg <= bound;
                    valid_out <= bind_valid;
                end
                2'b01: begin  // Bundle only
                    bundle_result_reg <= bundled;
                    valid_out <= bundle_valid;
                end
                2'b10: begin  // Similarity only
                    bind_result_reg <= bound;  // Pass through
                    valid_out <= sim_valid;
                end
                2'b11: begin  // Full pipeline
                    bind_result_reg <= bound;
                    bundle_result_reg <= bundled;
                    valid_out <= sim_valid;
                end
            endcase
        end
    end

    assign bind_result = bind_result_reg;
    assign bundle_result = bundle_result_reg;
    assign similarity_score = sim;

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// TOP MODULE WITH T23 LED DEBUG
// ═══════════════════════════════════════════════════════════════════════════════

module vsa_pipeline_256_top (
    input  wire clk,
    input  wire rst,
    output wire led  // T23
);

    // LFSR for test pattern generation
    reg [31:0] lfsr;
    reg [23:0] blink_counter;
    reg led_reg;

    // Test vectors
    wire [511:0] vec_a, vec_b, vec_c;

    // Generate test patterns from LFSR
    genvar k;
    generate
        for (k = 0; k < 256; k = k + 1) begin : trit_gen
            assign vec_a[2*k +: 2] = (lfsr[k % 32]) ? 2'b01 : 2'b00;
            assign vec_b[2*k +: 2] = (lfsr[(k+8) % 32]) ? 2'b01 : 2'b00;
            assign vec_c[2*k +: 2] = (lfsr[(k+16) % 32]) ? 2'b10 : 2'b00;
        end
    endgenerate

    // Pipeline instance
    wire valid_out;
    wire [511:0] bind_r, bundle_r;
    wire [15:0] similarity;

    vsa_pipeline_256 pipeline (
        .clk(clk),
        .rst(rst),
        .valid_in(1'b1),
        .bind_a(vec_a),
        .bind_b(vec_b),
        .bundle_c(vec_c),
        .bundle_enable(1'b1),
        .sim_ref(vec_c),
        .sim_enable(1'b1),
        .op(2'b11),  // Full pipeline
        .valid_out(valid_out),
        .bind_result(bind_r),
        .bundle_result(bundle_r),
        .similarity_score(similarity)
    );

    // LED indicates pipeline activity
    always @(posedge clk) begin
        if (rst) begin
            lfsr <= 32'h1370000;
            blink_counter <= 0;
            led_reg <= 0;
        end else begin
            // LFSR for pattern generation
            lfsr <= (lfsr << 1) ^ ((lfsr & 32'h80000000) ? 32'h80200003 : 32'd0);

            // Blink based on similarity score
            blink_counter <= blink_counter + 1;

            if (similarity > 16'd7500) begin  // High similarity
                if (blink_counter[18]) led_reg <= ~led_reg;  // Fast blink
            end else if (similarity > 16'd5000) begin  // Medium
                if (blink_counter[20]) led_reg <= ~led_reg;
            end else begin  // Low
                if (blink_counter[23]) led_reg <= ~led_reg;  // Slow blink
            end
        end
    end

    assign led = ~led_reg;

endmodule

// φ² + 1/φ² = 3 = TRINITY
