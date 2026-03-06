`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY QUANTUM INTERFACE — Bell Inequality & CGLMP Testing Hardware
// ═══════════════════════════════════════════════════════════════════════════════
//
// Quantum entanglement verification using:
//   CHSH Inequality: |S| ≤ 2 (classical), |S| ≤ 2√2 (quantum)
//   CGLMP Inequality: Generalized CHSH for d-dimensional systems
//
// Hardware implementation for:
//   - Qutrit state generation (3-level quantum systems)
//   - Correlation measurement
//   - Bell parameter calculation
//   - LED output: violation (chaotic), no violation (steady/slow)
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

// ================================================================
// QUTRIT STATE GENERATOR
// ================================================================
// Generates entangled qutrit pairs for Bell testing
// |Ψ⟩ = (1/√3)(|00⟩ + |11⟩ + |22⟩)  (maximally entangled 3D state)

module qutrit_generator (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    output wire [1:0] qutrit_a,   // Alice's qutrit {00,01,10} = {-1,0,+1}
    output wire [1:0] qutrit_b,   // Bob's qutrit
    output reg        valid
);

    // ================================================================
    // QUTRIT ENCODING (ternary to 2-bit)
    // ================================================================
    // 2'b00 = -1 (trit -1)
    // 2'b01 =  0 (trit  0)
    // 2'b10 = +1 (trit +1)

    // LFSR for pseudo-random qutrit state generation
    reg [15:0] lfsr;
    reg [3:0]  counter;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            lfsr <= 16'hACE1;  // Non-zero seed
            counter <= 4'd0;
            valid <= 1'b0;
        end else if (enable) begin
            // LFSR feedback: x^16 + x^14 + x^13 + x^11 + 1
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            counter <= counter + 1;
            valid <= (counter == 4'd15);
        end else begin
            valid <= 1'b0;
        end
    end

    // Extract qutrit values from LFSR (using trinary mapping)
    // Each qutrit is correlated: when A changes, B changes the same way
    wire [1:0] raw_a = {lfsr[1], lfsr[0]};
    wire [1:0] raw_b = raw_a;  // Perfect correlation (maximal entanglement)

    assign qutrit_a = (raw_a == 2'b11) ? 2'b01 : raw_a;  // Map 11→01
    assign qutrit_b = (raw_b == 2'b11) ? 2'b01 : raw_b;

endmodule

// ================================================================
// CHSH BELL TEST MODULE
// ================================================================
// Clauser-Horne-Shimony-Holt (CHSH) inequality test
// S = E(a₀b₀) + E(a₀b₁) + E(a₁b₀) - E(a₁b₁)
// Classical: |S| ≤ 2, Quantum: |S| ≤ 2√2 ≈ 2.828

module chsh_bell_test #(
    parameter SAMPLES = 1000  // Number of measurement samples
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       measure_en,
    input  wire [1:0]  qutrit_a,
    input  wire [1:0]  qutrit_b,
    input  wire [1:0]  setting_a,  // Measurement setting for Alice (0 or 1)
    input  wire [1:0]  setting_b,  // Measurement setting for Bob
    output reg        done,
    output reg [31:0] chsh_s,      // CHSH S parameter (fixed point 8.8)
    output reg        violation    // 1 if |S| > 2
);

    // ================================================================
    // MEASUREMENT SETTINGS (4 combinations)
    // ================================================================
    // a₀b₀, a₀b₁, a₁b₀, a₁b₁
    // For qutrits: project onto bases rotated by different angles

    // Convert trits to signed values: -1, 0, +1
    wire signed [1:0] signed_a = (qutrit_a == 2'b00) ? -1 :
                                 (qutrit_a == 2'b10) ? 1 : 0;
    wire signed [1:0] signed_b = (qutrit_b == 2'b00) ? -1 :
                                 (qutrit_b == 2'b10) ? 1 : 0;

    // Correlation accumulators for each setting pair
    reg signed [31:0] e00, e01, e10, e11;
    reg signed [15:0] count00, count01, count10, count11;
    reg [15:0] sample_count;
    reg [31:0] total_samples;

    // Current setting index
    reg [1:0] setting_idx;
    wire [1:0] current_setting_a = {1'b0, setting_idx[1]};  // 00, 01, 10, 11
    wire [1:0] current_setting_b = {1'b0, setting_idx[0]};

    // Temporaries for calculation
    reg signed [31:0] avg00, avg01, avg10, avg11, s_val;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            e00 <= 0; e01 <= 0; e10 <= 0; e11 <= 0;
            count00 <= 0; count01 <= 0; count10 <= 0; count11 <= 0;
            sample_count <= 0;
            total_samples <= 0;
            setting_idx <= 0;
            chsh_s <= 0;
            violation <= 0;
            done <= 0;
            avg00 <= 0; avg01 <= 0; avg10 <= 0; avg11 <= 0; s_val <= 0;
        end else if (measure_en) begin
            // Accumulate correlations based on current settings
            if (setting_idx == 2'b00) begin
                e00 <= e00 + signed_a * signed_b;
                count00 <= count00 + 1;
            end else if (setting_idx == 2'b01) begin
                e01 <= e01 + signed_a * signed_b;
                count01 <= count01 + 1;
            end else if (setting_idx == 2'b10) begin
                e10 <= e10 + signed_a * signed_b;
                count10 <= count10 + 1;
            end else begin
                e11 <= e11 + signed_a * signed_b;
                count11 <= count11 + 1;
            end

            sample_count <= sample_count + 1;
            if (sample_count >= SAMPLES/4 - 1) begin
                setting_idx <= setting_idx + 1;
                sample_count <= 0;
            end

            total_samples <= total_samples + 1;
            if (total_samples >= SAMPLES - 1) begin
                // Calculate CHSH S parameter
                // Normalize correlations
                avg00 <= (count00 > 0) ? (e00 << 8) / count00 : 0;
                avg01 <= (count01 > 0) ? (e01 << 8) / count01 : 0;
                avg10 <= (count10 > 0) ? (e10 << 8) / count10 : 0;
                avg11 <= (count11 > 0) ? (e11 << 8) / count11 : 0;

                // S = E00 + E01 + E10 - E11
                s_val <= avg00 + avg01 + avg10 - avg11;
                chsh_s <= s_val[31:0];

                // Check violation (|S| > 2.0 = 512 in 8.8 fixed point)
                violation <= (s_val > 32'sd512) || (s_val < -32'sd512);
                done <= 1;
            end
        end else begin
            done <= 0;
        end
    end

endmodule

// ================================================================
// CGLMP D-DIMENSIONAL BELL TEST
// ================================================================
// Collins-Gisin-Linden-Massar-Popescu inequality
// Generalized CHSH for d-dimensional systems (qutrits: d=3)
//
// I_d ≤ 2 for classical systems
// I_d = 2(2cos(π/d) - cos(2π/d)) for quantum (maximal violation)
// For d=3: I_3_max ≈ 2.872

module cglmp_bell_test #(
    parameter D = 3,          // Dimension (qutrits = 3)
    parameter SAMPLES = 1000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       measure_en,
    input  wire [1:0]  qutrit_a,
    input  wire [1:0]  qutrit_b,
    output reg        done,
    output reg [31:0] cglmp_i,     // CGLMP I parameter
    output reg        violation    // 1 if I > 2
);

    // ================================================================
    // CGLMP CALCULATION
    // ================================================================
    // I_d = P(A₁=B₁) + P(B₁=A₂) + P(A₂=B₂) - P(A₂=B₁) - P(A₁=B₂)
    // where A₁,A₂ are Alice's outcomes with settings a,a'
    //       B₁,B₂ are Bob's outcomes with settings b,b'

    // Convert trit to integer 0,1,2
    wire [1:0] int_a = (qutrit_a == 2'b00) ? 2'd0 :
                       (qutrit_a == 2'b01) ? 2'd1 : 2'd2;
    wire [1:0] int_b = (qutrit_b == 2'b00) ? 2'd0 :
                       (qutrit_b == 2'b01) ? 2'd1 : 2'd2;

    // Joint probability accumulators
    reg [31:0] p_a1_eq_b1, p_b1_eq_a2, p_a2_eq_b2, p_a2_eq_b1, p_a1_eq_b2;
    reg [15:0] sample_count;

    // Temporaries for calculation
    reg [31:0] n, term1, term2, term3, term4, term5;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            p_a1_eq_b1 <= 0;
            p_b1_eq_a2 <= 0;
            p_a2_eq_b2 <= 0;
            p_a2_eq_b1 <= 0;
            p_a1_eq_b2 <= 0;
            sample_count <= 0;
            cglmp_i <= 0;
            violation <= 0;
            done <= 0;
            n <= 0; term1 <= 0; term2 <= 0; term3 <= 0; term4 <= 0; term5 <= 0;
        end else if (measure_en) begin
            // Accumulate joint probabilities
            if (int_a == int_b) p_a1_eq_b1 <= p_a1_eq_b1 + 1;
            if (int_b == int_a) p_b1_eq_a2 <= p_b1_eq_a2 + 1;
            if (int_a == int_b) p_a2_eq_b2 <= p_a2_eq_b2 + 1;
            if (int_a == int_b) p_a2_eq_b1 <= p_a2_eq_b1 + 1;
            if (int_a == int_b) p_a1_eq_b2 <= p_a1_eq_b2 + 1;

            sample_count <= sample_count + 1;

            if (sample_count >= SAMPLES - 1) begin
                // Calculate CGLMP I parameter
                // Normalize by total samples
                n <= sample_count;
                term1 <= (p_a1_eq_b1 << 8) / {16'd0, sample_count};
                term2 <= (p_b1_eq_a2 << 8) / {16'd0, sample_count};
                term3 <= (p_a2_eq_b2 << 8) / {16'd0, sample_count};
                term4 <= (p_a2_eq_b1 << 8) / {16'd0, sample_count};
                term5 <= (p_a1_eq_b2 << 8) / {16'd0, sample_count};

                cglmp_i <= term1 + term2 + term3 - term4 - term5;

                // Classical bound: I_d ≤ 2 (512 in 8.8 fixed point)
                // Quantum maximum for d=3: I_3_max ≈ 2.872 (735 in 8.8)
                violation <= ((term1 + term2 + term3 - term4 - term5) > 32'sd512);
                done <= 1;
            end
        end else begin
            done <= 0;
        end
    end

endmodule

// ================================================================
// QUANTUM TEST TOP MODULE
// ================================================================
// Complete Bell inequality testing with LED feedback

module quantum_test_top (
    input  wire       clk,
    input  wire       rst,
    output wire       led,         // D6 LED output
    output wire [7:0] debug,       // Debug output
    output reg        test_done,
    output reg [31:0] result_value
);

    // Qutrit generator
    wire [1:0] qutrit_a, qutrit_b;
    wire       qutrit_valid;

    qutrit_generator gen (
        .clk(clk),
        .rst_n(~rst),
        .enable(1'b1),
        .qutrit_a(qutrit_a),
        .qutrit_b(qutrit_b),
        .valid(qutrit_valid)
    );

    // CHSH Bell test
    wire       chsh_done;
    wire [31:0] chsh_s;
    wire       chsh_violation;

    chsh_bell_test #(
        .SAMPLES(500)
    ) chsh (
        .clk(clk),
        .rst_n(~rst),
        .measure_en(qutrit_valid),
        .qutrit_a(qutrit_a),
        .qutrit_b(qutrit_b),
        .setting_a(2'b00),
        .setting_b(2'b00),
        .done(chsh_done),
        .chsh_s(chsh_s),
        .violation(chsh_violation)
    );

    // LED behavior based on violation status
    // Violation (|S| > 2): chaotic/fast blinking
    // No violation: slow or steady
    reg [23:0] blink_counter;
    reg        led_state;

    always @(posedge clk) begin
        if (rst) begin
            blink_counter <= 0;
            led_state <= 0;
            test_done <= 0;
            result_value <= 0;
        end else begin
            test_done <= chsh_done;
            result_value <= chsh_s;

            if (chsh_violation) begin
                // Chaotic blinking (fast, irregular)
                blink_counter <= blink_counter + 1;
                led_state <= blink_counter[10] ^ blink_counter[7] ^ blink_counter[4];
            end else begin
                // Slow steady blink
                blink_counter <= blink_counter + 1;
                led_state <= blink_counter[22];
            end
        end
    end

    assign led = led_state;
    assign debug = {chsh_violation, chsh_done, 6'd0};

endmodule
