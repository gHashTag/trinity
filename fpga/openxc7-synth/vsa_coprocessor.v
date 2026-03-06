`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY VSA COPROCESSOR — Hardware Accelerator for Hyperdimensional Computing
// ═══════════════════════════════════════════════════════════════════════════════
//
// Vector Symbolic Architecture operations in hardware:
//   bind(a, b)      = a × b            (element-wise ternary multiply)
//   unbind(v, k)    = v × permute(k)⁻¹ (inverse binding via permutation)
//   bundle(v1,..vn) = majority(v...)   (majority vote)
//   similarity(v1, v2) = cosine(v1, v2) (dot product / magnitude)
//
// Optimized for 10K-dimensional hypervectors with DSP48E1 acceleration
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

module vsa_coprocessor #(
    parameter DIM = 10240,          // 10K dimensions
    parameter BLOCK_SIZE = 16,      // Process 16 trits per block
    parameter NUM_DSP = 16          // Number of DSP blocks
)(
    input  wire        clk,
    input  wire        rst_n,

    // Command interface
    input  wire [2:0]   cmd,           // Operation command
    input  wire        cmd_valid,     // Command valid strobe
    output reg         cmd_ready,     // Coprocessor ready for new command

    // Vector memory interface (dual-port BRAM)
    output wire [13:0] vec_addr_a,    // Vector A address
    output wire [13:0] vec_addr_b,    // Vector B address
    input  wire [31:0] vec_data_a,    // Vector A data (16 trits packed)
    input  wire [31:0] vec_data_b,    // Vector B data (16 trits packed)
    output reg  [31:0] vec_wr_data,   // Vector write data
    output wire        vec_wr_en,     // Vector write enable

    // Result interface
    output wire [13:0] result_addr,   // Result vector address
    output reg         result_valid,  // Result ready strobe

    // Status
    output reg         busy,          // Coprocessor busy
    output reg  [31:0] similarity_out // Similarity score (for similarity cmd)
);

    // ================================================================
    // COMMAND ENCODING
    // ================================================================
    localparam CMD_NOP     = 3'd0;
    localparam CMD_BIND    = 3'd1;  // result = vec_a × vec_b
    localparam CMD_UNBIND  = 3'd2;  // result = vec_a × permute_inv(vec_b)
    localparam CMD_BUNDLE2 = 3'd3;  // result = majority(vec_a, vec_b)
    localparam CMD_BUNDLE3 = 3'd4;  // result = majority(vec_a, vec_b, vec_c)
    localparam CMD_SIMILARITY = 3'd5; // similarity_out = cosine(vec_a, vec_b)

    // ================================================================
    // ADDRESS GENERATION
    // ================================================================
    // Number of 32-bit words needed to store DIM trits (2 bits per trit)
    localparam NUM_WORDS = (DIM * 2 + 31) / 32;  // 640 words for 10K trits

    reg [13:0] addr_counter;
    reg [2:0]  state;
    reg [2:0]  current_cmd;

    localparam STATE_IDLE     = 3'd0;
    localparam STATE_READ     = 3'd1;
    localparam STATE_PROCESS  = 3'd2;
    localparam STATE_WRITE    = 3'd3;
    localparam STATE_DONE     = 3'd4;

    // ================================================================
    // VECTOR READ/WRITE ADDRESSES
    // ================================================================
    assign vec_addr_a = (state == STATE_READ || state == STATE_PROCESS) ? addr_counter : 14'd0;
    assign vec_addr_b = (state == STATE_READ || state == STATE_PROCESS) ? addr_counter : 14'd0;
    assign result_addr = (state == STATE_WRITE) ? addr_counter : 14'd0;
    assign vec_wr_en = (state == STATE_WRITE);

    // ================================================================
    // BIND OPERATION (DSP ACCELERATED)
    // ================================================================
    // bind(a, b) = a × b for each trit
    // Using DSP48E1 for parallel computation

    wire [BLOCK_SIZE*2-1:0] bind_result;
    reg bind_valid;

    // Instantiate DSP-accelerated bind block
    vsa_dsp_bind_block #(
        .SIZE(BLOCK_SIZE)
    ) bind_inst (
        .CLK(clk),
        .RST(~rst_n),
        .valid_in(state == STATE_PROCESS && current_cmd == CMD_BIND),
        .a_trits(vec_data_a[BLOCK_SIZE*2-1:0]),
        .b_trits(vec_data_b[BLOCK_SIZE*2-1:0]),
        .result_trits(bind_result)
    );

    // ================================================================
    // UNBIND OPERATION (with permutation)
    // ================================================================
    // unbind(v, k) = v × permute(k, -steps)⁻¹
    // First apply inverse permutation to key, then bind

    wire [BLOCK_SIZE*2-1:0] permuted_key;
    wire [BLOCK_SIZE*2-1:0] unbind_result;

    // Simple permutation: rotate trits within block
    // For full VSA, would need global permutation across all DIM trits
    reg [3:0] perm_shift;
    always @(posedge clk) begin
        if (state == STATE_IDLE) begin
            perm_shift <= 4'd1;  // Default permutation shift
        end
    end

    // Permute key by -shift (rotate right)
    assign permuted_key = {
        vec_data_b[0 +: 2],
        vec_data_b[2 +: 2],
        vec_data_b[4 +: 2],
        vec_data_b[6 +: 2],
        vec_data_b[8 +: 2],
        vec_data_b[10 +: 2],
        vec_data_b[12 +: 2],
        vec_data_b[14 +: 2],
        vec_data_b[16 +: 2],
        vec_data_b[18 +: 2],
        vec_data_b[20 +: 2],
        vec_data_b[22 +: 2],
        vec_data_b[24 +: 2],
        vec_data_b[26 +: 2],
        vec_data_b[28 +: 2],
        vec_data_b[30 +: 2]
    };

    // Unbind = bind with permuted key
    vsa_dsp_bind_block #(
        .SIZE(BLOCK_SIZE)
    ) unbind_inst (
        .CLK(clk),
        .RST(~rst_n),
        .valid_in(state == STATE_PROCESS && current_cmd == CMD_UNBIND),
        .a_trits(vec_data_a[BLOCK_SIZE*2-1:0]),
        .b_trits(permuted_key),
        .result_trits(unbind_result)
    );

    // ================================================================
    // BUNDLE OPERATION (Majority Vote)
    // ================================================================
    // bundle(a, b) = majority(a[i], b[i]) for each trit position
    // {-1,-1}→{-1}, {-1,0}→{-1}, {-1,+1}→{0}, {0,0}→{0}, {0,+1}→{+1}, {+1,+1}→{+1}

    wire [BLOCK_SIZE*2-1:0] bundle2_result;

    genvar i;
    generate for (i = 0; i < BLOCK_SIZE; i = i + 1) begin : gen_bundle
        wire [1:0] a = vec_data_a[i*2 +: 2];
        wire [1:0] b = vec_data_b[i*2 +: 2];

        // Majority logic for ternary values
        // 00=-1, 01=0, 10=+1
        wire [1:0] maj;
        assign maj = (a == b) ? a :           // Same → take value
                     ({a, b} == 4'b0010) ? 2'b00 :  // -1,0 → -1
                     ({a, b} == 4'b0100) ? 2'b00 :  // 0,-1 → -1
                     ({a, b} == 4'b0110) ? 2'b01 :  // -1,+1 → 0
                     ({a, b} == 4'b1001) ? 2'b01 :  // +1,-1 → 0
                     2'b10;                           // Default +1

        assign bundle2_result[i*2 +: 2] = maj;
    end
    endgenerate

    // ================================================================
    // SIMILARITY OPERATION (Cosine Similarity)
    // ================================================================
    // similarity(a, b) = (a · b) / (|a| × |b|)
    // For ternary vectors: dot product over magnitudes

    reg [31:0] dot_accumulator;
    reg [15:0] sample_count;

    // DSP-based dot product accumulator
    integer j;
    reg signed [31:0] block_sum;

    always @(posedge clk) begin
        if (~rst_n) begin
            dot_accumulator <= 32'd0;
            sample_count <= 16'd0;
        end else if (state == STATE_IDLE) begin
            dot_accumulator <= 32'd0;
            sample_count <= 16'd0;
        end else if (state == STATE_PROCESS && current_cmd == CMD_SIMILARITY) begin
            // Accumulate dot product for this block
            // Each trit pair contributes: -1×-1=+1, -1×0=0, -1×+1=-1, etc.
            block_sum = 0;
            for (j = 0; j < BLOCK_SIZE; j = j + 1) begin
                case ({vec_data_a[j*2 +: 2], vec_data_b[j*2 +: 2]})
                    8'b0000_0000: block_sum = block_sum + 1;  // -1 × -1 = +1
                    8'b0000_0001: block_sum = block_sum + 0;  // -1 × 0 = 0
                    8'b0000_0010: block_sum = block_sum - 1;  // -1 × +1 = -1
                    8'b0001_0000: block_sum = block_sum + 0;  // 0 × -1 = 0
                    8'b0001_0001: block_sum = block_sum + 0;  // 0 × 0 = 0
                    8'b0001_0010: block_sum = block_sum + 0;  // 0 × +1 = 0
                    8'b0010_0000: block_sum = block_sum - 1;  // +1 × -1 = -1
                    8'b0010_0001: block_sum = block_sum + 0;  // +1 × 0 = 0
                    8'b0010_0010: block_sum = block_sum + 1;  // +1 × +1 = +1
                    default: block_sum = block_sum + 0;
                endcase
            end
            dot_accumulator <= dot_accumulator + block_sum;
            sample_count <= sample_count + 1;
        end
    end

    // ================================================================
    // RESULT MUX AND WRITE DATA
    // ================================================================
    always @(*) begin
        case (current_cmd)
            CMD_BIND:      vec_wr_data = {30'd0, bind_result};
            CMD_UNBIND:    vec_wr_data = {30'd0, unbind_result};
            CMD_BUNDLE2:   vec_wr_data = {30'd0, bundle2_result};
            CMD_BUNDLE3:   vec_wr_data = {30'd0, bundle2_result};  // TODO: 3-input
            default:       vec_wr_data = 32'd0;
        endcase
    end

    // ================================================================
    // MAIN STATE MACHINE
    // ================================================================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= STATE_IDLE;
            addr_counter <= 14'd0;
            busy <= 1'b0;
            cmd_ready <= 1'b1;
            result_valid <= 1'b0;
            current_cmd <= CMD_NOP;
            similarity_out <= 32'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    busy <= 1'b0;
                    cmd_ready <= 1'b1;
                    result_valid <= 1'b0;

                    if (cmd_valid && cmd_ready) begin
                        current_cmd <= cmd;
                        state <= STATE_READ;
                        addr_counter <= 14'd0;
                        busy <= 1'b1;
                        cmd_ready <= 1'b0;
                    end
                end

                STATE_READ: begin
                    // Read vector data (simplified - assumes single cycle)
                    state <= STATE_PROCESS;
                end

                STATE_PROCESS: begin
                    // Process current block
                    if (addr_counter >= NUM_WORDS - 1) begin
                        if (current_cmd == CMD_SIMILARITY) begin
                            // Output similarity score
                            similarity_out <= dot_accumulator;
                            state <= STATE_DONE;
                        end else begin
                            state <= STATE_WRITE;
                            addr_counter <= 14'd0;
                        end
                    end else begin
                        addr_counter <= addr_counter + 1;
                    end
                end

                STATE_WRITE: begin
                    result_valid <= 1'b1;
                    if (addr_counter >= NUM_WORDS - 1) begin
                        state <= STATE_DONE;
                    end else begin
                        addr_counter <= addr_counter + 1;
                    end
                end

                STATE_DONE: begin
                    result_valid <= 1'b0;
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// VSA PERMUTATION MODULE (for unbind operation)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Cyclic permutation of hypervector trits
// Used for unbind operation: unbind(v, k) = bind(v, permute(k, -steps))

module vsa_permute #(
    parameter DIM = 10240,
    parameter SHIFT_STEPS = 1
)(
    input  wire [DIM*2-1:0] vec_in,
    input  wire             direction,  // 0 = left, 1 = right
    output wire [DIM*2-1:0] vec_out
);

    // Cyclic shift by SHIFT_STEPS trits (SHIFT_STEPS*2 bits)
    localparam SHIFT_BITS = SHIFT_STEPS * 2;

    assign vec_out = direction ?
        {vec_in[SHIFT_BITS-1:0], vec_in[DIM*2-1:SHIFT_BITS]} :  // Right shift
        {vec_in[DIM*2-1-SHIFT_BITS:0], vec_in[DIM*2-1:DIM*2-SHIFT_BITS]};  // Left

endmodule
