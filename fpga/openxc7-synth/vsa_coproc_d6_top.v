`default_nettype none

// =============================================================================
// TRINITY VSA COPROCESSOR — FPGA TOP MODULE (D6 LED)
// =============================================================================
//
// Board: QMTECH Artix-7 XC7A100T-1FGG676C
//   - clk: U22 (50 MHz oscillator)
//   - led: T23 (D6 LED)
//
// Self-test: fill vectors -> BIND -> SIMILARITY -> show result on LED
//   - Fast blink (~5 Hz): Bind+Similarity passed
//   - Slow blink (~1 Hz): Similarity = 0
//   - Chaotic blink: Tests running
//
// phi^2 + 1/phi^2 = 3
// =============================================================================

module vsa_coproc_d6_top (
    input  wire clk,
    output wire led
);

    // ================================================================
    // RESET GENERATOR (hold reset for 16 cycles)
    // ================================================================
    reg [3:0] rst_counter = 4'b0;
    reg rst_n = 1'b0;

    always @(posedge clk) begin
        if (rst_counter < 4'd15) begin
            rst_counter <= rst_counter + 1'b1;
            rst_n <= 1'b0;
        end else begin
            rst_n <= 1'b1;
        end
    end

    // ================================================================
    // PARAMETERS
    // ================================================================
    localparam TEST_DIM   = 1024;
    localparam BLOCK_SIZE = 16;
    localparam NUM_WORDS  = (TEST_DIM * 2 + 31) / 32;  // 64

    // ================================================================
    // VECTOR MEMORY — single write port
    // ================================================================
    // 0x00-0x3F = Vector A (64 words)
    // 0x40-0x7F = Vector B (64 words)
    // 0x80-0xBF = Result   (64 words)
    reg [31:0] vec_mem [0:255];

    // Coprocessor interface wires
    wire [13:0] vec_addr_a;
    wire [13:0] vec_addr_b;
    wire [31:0] vec_data_a;
    wire [31:0] vec_data_b;
    wire [31:0] vec_wr_data;
    wire        vec_wr_en;
    wire [13:0] result_addr;
    wire        result_valid;
    wire        cmd_ready;
    wire        busy;
    wire [31:0] similarity_out;

    // Read ports (always available)
    assign vec_data_a = vec_mem[vec_addr_a[7:0]];
    assign vec_data_b = vec_mem[{1'b1, vec_addr_b[6:0]}];

    // ================================================================
    // VSA COPROCESSOR
    // ================================================================
    reg [2:0]  cmd_reg;
    reg        cmd_valid_reg;

    vsa_coprocessor #(
        .DIM(TEST_DIM),
        .BLOCK_SIZE(BLOCK_SIZE),
        .NUM_DSP(4)
    ) coproc (
        .clk(clk),
        .rst_n(rst_n),
        .cmd(cmd_reg),
        .cmd_valid(cmd_valid_reg),
        .cmd_ready(cmd_ready),
        .vec_addr_a(vec_addr_a),
        .vec_addr_b(vec_addr_b),
        .vec_data_a(vec_data_a),
        .vec_data_b(vec_data_b),
        .vec_wr_data(vec_wr_data),
        .vec_wr_en(vec_wr_en),
        .result_addr(result_addr),
        .result_valid(result_valid),
        .busy(busy),
        .similarity_out(similarity_out)
    );

    // ================================================================
    // SELF-TEST STATE MACHINE
    // ================================================================
    localparam CMD_NOP        = 3'd0;
    localparam CMD_BIND       = 3'd1;
    localparam CMD_SIMILARITY = 3'd5;

    localparam ST_INIT      = 4'd0;
    localparam ST_FILL_A    = 4'd1;
    localparam ST_FILL_B    = 4'd2;
    localparam ST_CMD_BIND  = 4'd3;
    localparam ST_WAIT_BIND = 4'd4;
    localparam ST_CMD_SIM   = 4'd5;
    localparam ST_WAIT_SIM  = 4'd6;
    localparam ST_DONE      = 4'd7;
    localparam ST_LOOP      = 4'd8;

    reg [3:0]  test_state;
    reg [7:0]  fill_counter;
    reg [31:0] saved_similarity;
    reg        test_passed;
    reg [2:0]  test_cycle;

    // Test fill write signals
    reg        fill_wr_en;
    reg [7:0]  fill_wr_addr;
    reg [31:0] fill_wr_data;

    // Ternary patterns (phi-based)
    // Encoding: -1=00, 0=01, +1=10
    wire [31:0] pattern_a = 32'b10_00_10_01_10_00_01_10_00_10_10_00_10_01_00_10;
    wire [31:0] pattern_b = 32'b00_10_00_10_01_10_00_10_10_01_00_10_01_10_00_00;

    // ================================================================
    // SINGLE WRITE PORT — arbitrated between fill and coprocessor
    // ================================================================
    always @(posedge clk) begin
        if (fill_wr_en) begin
            // Test fill has priority during fill states
            vec_mem[fill_wr_addr] <= fill_wr_data;
        end else if (vec_wr_en) begin
            // Coprocessor writes during operation
            vec_mem[{2'b10, result_addr[5:0]}] <= vec_wr_data;
        end
    end

    // ================================================================
    // STATE MACHINE
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            test_state      <= ST_INIT;
            fill_counter    <= 8'd0;
            cmd_reg         <= CMD_NOP;
            cmd_valid_reg   <= 1'b0;
            saved_similarity <= 32'd0;
            test_passed     <= 1'b0;
            test_cycle      <= 3'd0;
            fill_wr_en      <= 1'b0;
            fill_wr_addr    <= 8'd0;
            fill_wr_data    <= 32'd0;
        end else begin
            cmd_valid_reg <= 1'b0;
            fill_wr_en    <= 1'b0;

            case (test_state)
                ST_INIT: begin
                    fill_counter <= 8'd0;
                    test_state   <= ST_FILL_A;
                end

                ST_FILL_A: begin
                    fill_wr_en   <= 1'b1;
                    fill_wr_addr <= fill_counter[7:0];
                    fill_wr_data <= pattern_a ^ {24'd0, fill_counter};
                    if (fill_counter >= NUM_WORDS - 1) begin
                        fill_counter <= 8'd0;
                        test_state   <= ST_FILL_B;
                    end else begin
                        fill_counter <= fill_counter + 1'b1;
                    end
                end

                ST_FILL_B: begin
                    fill_wr_en   <= 1'b1;
                    fill_wr_addr <= {1'b1, fill_counter[6:0]};
                    fill_wr_data <= pattern_b ^ {24'd0, fill_counter};
                    if (fill_counter >= NUM_WORDS - 1) begin
                        test_state <= ST_CMD_BIND;
                    end else begin
                        fill_counter <= fill_counter + 1'b1;
                    end
                end

                ST_CMD_BIND: begin
                    if (cmd_ready) begin
                        cmd_reg       <= CMD_BIND;
                        cmd_valid_reg <= 1'b1;
                        test_state    <= ST_WAIT_BIND;
                    end
                end

                ST_WAIT_BIND: begin
                    if (!busy && cmd_ready) begin
                        test_state <= ST_CMD_SIM;
                    end
                end

                ST_CMD_SIM: begin
                    if (cmd_ready) begin
                        cmd_reg       <= CMD_SIMILARITY;
                        cmd_valid_reg <= 1'b1;
                        test_state    <= ST_WAIT_SIM;
                    end
                end

                ST_WAIT_SIM: begin
                    if (!busy && cmd_ready) begin
                        saved_similarity <= similarity_out;
                        test_cycle       <= test_cycle + 1'b1;
                        if (test_cycle >= 3'd2) begin
                            test_passed <= (similarity_out != 32'd0);
                            test_state  <= ST_DONE;
                        end else begin
                            test_state <= ST_LOOP;
                        end
                    end
                end

                ST_DONE: begin
                    // LED reflects final result
                end

                ST_LOOP: begin
                    fill_counter <= 8'd0;
                    test_state   <= ST_FILL_A;
                end

                default: test_state <= ST_INIT;
            endcase
        end
    end

    // ================================================================
    // LED DRIVER
    // ================================================================
    reg [25:0] led_counter;

    always @(posedge clk) begin
        led_counter <= led_counter + 1'b1;
    end

    reg led_out;

    always @(*) begin
        if (test_state == ST_DONE && test_passed)
            led_out = led_counter[22];          // Fast ~5 Hz
        else if (test_state == ST_DONE)
            led_out = led_counter[25];          // Slow ~1 Hz
        else
            led_out = led_counter[23] ^ led_counter[19] ^ led_counter[15] ^ led_counter[11];
    end

    assign led = led_out;

endmodule
