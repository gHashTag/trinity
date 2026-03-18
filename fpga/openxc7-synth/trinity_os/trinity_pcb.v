// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY OS — Process Control Block v1.0.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Process Control Blocks with Sacred State Encoding
// Golden Identity: φ² + 1/φ² = 3
//
// PCB Layout (256 bits total):
//   [255:240]  task_id           (16 bits) - Unique task identifier
//   [239:224]  parent_id         (16 bits) - Parent task (0 if root)
//   [223:208]  state             (16 bits) - Task state (running, blocked, etc.)
//   [207:192]  priority          (16 bits) - Priority (phi-weighted)
//   [191:160]  cycle_count       (32 bits) - Cycles executed
//   [159:128]  sacred_counter    (32 bits) - Lucas sequence position
//   [127:96]   trit_accumulator  (32 bits) - Ternary operation result
//   [95:64]    vsa_vector_ptr    (32 bits) - VSA vector pointer
//   [63:32]    stack_ptr         (32 bits) - Stack pointer
//   [31:0]     flags             (32 bits) - Status flags
//
// Author: TRINITY OS Team
// Part: TRINITY OS Phase 1 - Kernel Foundation
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module trinity_pcb #(
    parameter MAX_TASKS = 16,
    parameter PCB_WIDTH = 256,
    parameter LOG2_MAX_TASKS = 4
)(
    input  wire                        clk,
    input  wire                        rst_n,

    // Read interface
    input  wire                        pcb_read,
    input  wire [LOG2_MAX_TASKS-1:0]   pcb_read_addr,
    output wire [PCB_WIDTH-1:0]        pcb_read_data,

    // Write interface
    input  wire                        pcb_write,
    input  wire [LOG2_MAX_TASKS-1:0]   pcb_write_addr,
    input  wire [PCB_WIDTH-1:0]        pcb_write_data,

    // Field access (individual fields)
    input  wire                        field_read,
    input  wire                        field_write,
    input  wire [LOG2_MAX_TASKS-1:0]   field_task_id,
    input  wire [3:0]                  field_select,  // 0-9 for each field
    input  wire [31:0]                 field_wdata,
    output wire [31:0]                 field_rdata,

    // Status
    output wire [3:0]                  task_count,
    output wire [MAX_TASKS-1:0]        task_valid_mask
);

    // ========================================================================
    // FIELD OFFSETS (bit positions within PCB)
    // ========================================================================

    localparam [7:0] F_TASK_ID        = 8'd240;  // [255:240]
    localparam [7:0] F_PARENT_ID      = 8'd224;  // [239:224]
    localparam [7:0] F_STATE          = 8'd208;  // [223:208]
    localparam [7:0] F_PRIORITY       = 8'd192;  // [207:192]
    localparam [7:0] F_CYCLE_COUNT    = 8'd160;  // [191:160]
    localparam [7:0] F_SACRED_COUNTER = 8'd128;  // [159:128]
    localparam [7:0] F_TRIT_ACCUM     = 8'd96;   // [127:96]
    localparam [7:0] F_VSA_VECTOR_PTR = 8'd64;   // [95:64]
    localparam [7:0] F_STACK_PTR      = 8'd32;   // [63:32]
    localparam [7:0] F_FLAGS          = 8'd0;    // [31:0]

    // Field selection codes
    localparam [3:0] SEL_TASK_ID        = 4'd0;
    localparam [3:0] SEL_PARENT_ID      = 4'd1;
    localparam [3:0] SEL_STATE          = 4'd2;
    localparam [3:0] SEL_PRIORITY       = 4'd3;
    localparam [3:0] SEL_CYCLE_COUNT    = 4'd4;
    localparam [3:0] SEL_SACRED_COUNTER = 4'd5;
    localparam [3:0] SEL_TRIT_ACCUM     = 4'd6;
    localparam [3:0] SEL_VSA_VECTOR_PTR = 4'd7;
    localparam [3:0] SEL_STACK_PTR      = 4'd8;
    localparam [3:0] SEL_FLAGS          = 4'd9;

    // ========================================================================
    // TASK STATE VALUES
    // ========================================================================

    localparam [15:0] STATE_INVALID = 16'h0000;
    localparam [15:0] STATE_READY   = 16'h0001;
    localparam [15:0] STATE_RUNNING = 16'h0002;
    localparam [15:0] STATE_BLOCKED = 16'h0003;
    localparam [15:0] STATE_WAITING = 16'h0004;
    localparam [15:0] STATE_ZOMBIE  = 16'hFFFF;  // Sacred death number

    // ========================================================================
    // PCB STORAGE (BRAM inference)
    // ========================================================================

    reg [PCB_WIDTH-1:0] pcb_memory [0:MAX_TASKS-1];
    reg [MAX_TASKS-1:0] valid;

    // Initialize with invalid state
    integer i;
    initial begin
        for (i = 0; i < MAX_TASKS; i = i + 1) begin
            pcb_memory[i] = {PCB_WIDTH{1'b0}};
            pcb_memory[i][223:208] = STATE_INVALID;
            valid[i] = 1'b0;
        end
    end

    // ========================================================================
    // READ/WRITE LOGIC
    // ========================================================================

    reg [PCB_WIDTH-1:0] read_data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_data_reg <= {PCB_WIDTH{1'b0}};
            for (i = 0; i < MAX_TASKS; i = i + 1) begin
                valid[i] <= 1'b0;
                pcb_memory[i][223:208] <= STATE_INVALID;
            end
        end else begin
            // Full PCB write
            if (pcb_write) begin
                pcb_memory[pcb_write_addr] <= pcb_write_data;
                valid[pcb_write_addr] <= 1'b1;
            end

            // Full PCB read
            if (pcb_read) begin
                read_data_reg <= pcb_memory[pcb_read_addr];
            end

            // Field write
            if (field_write && field_task_id < MAX_TASKS) begin
                case (field_select)
                    SEL_TASK_ID:        pcb_memory[field_task_id][255:240] <= field_wdata[15:0];
                    SEL_PARENT_ID:      pcb_memory[field_task_id][239:224] <= field_wdata[15:0];
                    SEL_STATE:          pcb_memory[field_task_id][223:208] <= field_wdata[15:0];
                    SEL_PRIORITY:       pcb_memory[field_task_id][207:192] <= field_wdata[15:0];
                    SEL_CYCLE_COUNT:    pcb_memory[field_task_id][191:160] <= field_wdata[31:0];
                    SEL_SACRED_COUNTER: pcb_memory[field_task_id][159:128] <= field_wdata[31:0];
                    SEL_TRIT_ACCUM:     pcb_memory[field_task_id][127:96]  <= field_wdata[31:0];
                    SEL_VSA_VECTOR_PTR: pcb_memory[field_task_id][95:64]   <= field_wdata[31:0];
                    SEL_STACK_PTR:      pcb_memory[field_task_id][63:32]   <= field_wdata[31:0];
                    SEL_FLAGS:          pcb_memory[field_task_id][31:0]    <= field_wdata[31:0];
                    default: ;
                endcase
                if (field_select == SEL_STATE && field_wdata[15:0] != STATE_INVALID)
                    valid[field_task_id] <= 1'b1;
                if (field_select == SEL_STATE && field_wdata[15:0] == STATE_INVALID)
                    valid[field_task_id] <= 1'b0;
            end
        end
    end

    // ========================================================================
    // FIELD READ LOGIC (combinational)
    // ========================================================================

    reg [31:0] field_rdata_reg;
    reg [15:0] field_16;

    always @(*) begin
        if (field_task_id < MAX_TASKS) begin
            case (field_select)
                SEL_TASK_ID:        field_16 = pcb_memory[field_task_id][255:240];
                SEL_PARENT_ID:      field_16 = pcb_memory[field_task_id][239:224];
                SEL_STATE:          field_16 = pcb_memory[field_task_id][223:208];
                SEL_PRIORITY:       field_16 = pcb_memory[field_task_id][207:192];
                SEL_CYCLE_COUNT:    field_rdata_reg = {16'd0, pcb_memory[field_task_id][191:160]};
                SEL_SACRED_COUNTER: field_rdata_reg = {16'd0, pcb_memory[field_task_id][159:128]};
                SEL_TRIT_ACCUM:     field_rdata_reg = {16'd0, pcb_memory[field_task_id][127:96]};
                SEL_VSA_VECTOR_PTR: field_rdata_reg = {16'd0, pcb_memory[field_task_id][95:64]};
                SEL_STACK_PTR:      field_rdata_reg = {16'd0, pcb_memory[field_task_id][63:32]};
                SEL_FLAGS:          field_rdata_reg = pcb_memory[field_task_id][31:0];
                default: begin
                    field_16 = 16'd0;
                    field_rdata_reg = 32'd0;
                end
            endcase

            // Handle 16-bit fields
            if (field_select == SEL_TASK_ID ||
                field_select == SEL_PARENT_ID ||
                field_select == SEL_STATE ||
                field_select == SEL_PRIORITY)
                field_rdata_reg = {16'd0, field_16};
        end else begin
            field_rdata_reg = 32'd0;
        end
    end

    // ========================================================================
    // COUNT ACTIVE TASKS
    // ========================================================================

    reg [3:0] task_count_reg;
    integer j;
    always @(*) begin
        task_count_reg = 0;
        for (j = 0; j < MAX_TASKS; j = j + 1) begin
            if (valid[j] && pcb_memory[j][223:208] != STATE_INVALID)
                task_count_reg = task_count_reg + 1;
        end
    end

    // ========================================================================
    // OUTPUTS
    // ========================================================================

    assign pcb_read_data = read_data_reg;
    assign field_rdata = field_rdata_reg;
    assign task_count = task_count_reg;
    assign task_valid_mask = valid;

    // ========================================================================
    // FORMAL PROPERTIES
    // ========================================================================

`ifdef FORMAL
    // PCB width matches parameter
    always @(*) begin
        assert ($bits(pcb_read_data) == PCB_WIDTH);
    end

    // State field cannot be zero when valid
    always @(posedge clk) begin
        if (rst_n && valid[pcb_write_addr] && pcb_write)
            assert (pcb_write_data[223:208] != STATE_INVALID);
    end
`endif

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY IDENTITY: φ² + 1/φ² = 3
// PCB_COUNT = 16 tasks × 256 bits = 4096 bits = 512 bytes
// Each PCB represents a "process quantum" in the TRINITY universe
// ═══════════════════════════════════════════════════════════════════════════════
