// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY OS — Ternary Scheduler v1.0.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Trit-Based Round-Robin Scheduler for TRINITY OS
// Golden Identity: φ² + 1/φ² = 3
//
// Priority Encoding (2-bit trits):
//   00 = BLOCKED  (-1) - Task will not be scheduled
//   01 = NORMAL   ( 0) - Standard priority, base time slice
//   10 = REALTIME (+1) - High priority, φ-weighted time slice
//   11 = RESERVED
//
// Time Slicing:
//   NORMAL:   time_slice = BASE_CYCLES
//   REALTIME: time_slice = BASE_CYCLES * φ (≈1.618x)
//
// Preemption at Sacred Numbers (Lucas Sequence):
//   2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123...
//
// Author: TRINITY OS Team
// Part: TRINITY OS Phase 1 - Kernel Foundation
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module ternary_scheduler #(
    parameter MAX_TASKS = 16,
    parameter BASE_CYCLES = 1000,  // Base time slice in cycles (20μs @ 50MHz)
    parameter LOG2_MAX_TASKS = 4
)(
    input  wire                        clk,
    input  wire                        rst_n,

    // Task control interface
    input  wire [LOG2_MAX_TASKS-1:0]   task_id,
    input  wire [1:0]                  task_priority,  // 00=blocked, 01=normal, 10=realtime
    input  wire                        task_spawn,
    input  wire                        task_kill,
    input  wire                        task_yield,

    // Scheduler outputs
    output wire [LOG2_MAX_TASKS-1:0]   current_task,
    output reg                         task_switch,    // Pulse when task switches
    output reg                         scheduler_idle,
    output wire [3:0]                  active_count,

    // Interrupt request (preemption)
    output reg                         preemption_irq,

    // Debug/status
    output wire [31:0]                 cycle_counter,
    output wire [31:0]                 sacred_counter,
    output wire [7:0]                  scheduler_state
);

    // ========================================================================
    // SACRED CONSTANTS
    // ========================================================================

    // Phi scaling for realtime tasks (fixed point: 8-bit fractional)
    // φ = 1.6180339887... ≈ 1 + 99/256 = 1.38671875 (close enough)
    // More accurate: 1.6171875 = 1 + 158/256
    localparam [11:0] PHI_SCALE = 12'd414;  // 1.6171875 * 256

    // Lucas sequence for preemption points
    localparam [7:0] LUCAS_0  = 8'd2;
    localparam [7:0] LUCAS_1  = 8'd1;
    localparam [7:0] LUCAS_2  = 8'd3;
    localparam [7:0] LUCAS_3  = 8'd4;
    localparam [7:0] LUCAS_4  = 8'd7;
    localparam [7:0] LUCAS_5  = 8'd11;
    localparam [7:0] LUCAS_6  = 8'd18;
    localparam [7:0] LUCAS_7  = 8'd29;

    // Priority encoding
    localparam [1:0] PRIO_BLOCKED  = 2'b00;
    localparam [1:0] PRIO_NORMAL   = 2'b01;
    localparam [1:0] PRIO_REALTIME = 2'b10;
    localparam [1:0] PRIO_RESERVED = 2'b11;

    // ========================================================================
    // STATE MACHINE
    // ========================================================================

    localparam [7:0] IDLE        = 8'd0;
    localparam [7:0] SCHEDULE    = 8'd1;
    localparam [7:0] RUNNING     = 8'd2;
    localparam [7:0] PREEMPTING  = 8'd3;
    localparam [7:0] YIELDING    = 8'd4;

    reg [7:0] state;
    reg [7:0] next_state;

    // ========================================================================
    // TASK CONTROL BLOCKS (TCB) - BRAM inference
    // ========================================================================

    // Each task has: valid (1 bit), priority (2 bits), time_slice (16 bits)
    reg [MAX_TASKS-1:0]           task_valid;
    reg [MAX_TASKS*2-1:0]         task_priority_ram;  // 2 bits per task
    reg [MAX_TASKS*16-1:0]        task_time_slice;    // 16 bits per task

    // Task priority access
    wire [1:0] task_prio [MAX_TASKS-1:0];
    genvar t;
    generate
        for (t = 0; t < MAX_TASKS; t = t + 1) begin : prio_access
            assign task_prio[t] = task_priority_ram[t*2 +: 2];
        end
    endgenerate

    // Active task tracking
    reg [31:0] cycle_count;
    reg [31:0] sacred_count;
    reg [15:0] current_slice_remaining;
    reg [LOG2_MAX_TASKS-1:0] next_task_ptr;
    reg [LOG2_MAX_TASKS-1:0] current_task_reg;

    // Counters
    wire [3:0] active_tasks;
    reg [3:0] active_tasks_reg;

    // ========================================================================
    // CALCULATE TIME SLICE (Phi-weighted)
    // ========================================================================

    function [15:0] calculate_time_slice;
        input [1:0] prio_val;
        begin
            case (prio_val)
                PRIO_NORMAL:   calculate_time_slice = BASE_CYCLES[15:0];
                PRIO_REALTIME: calculate_time_slice = (BASE_CYCLES * PHI_SCALE) >> 8;
                default:       calculate_time_slice = 16'd0;
            endcase
        end
    endfunction

    // ========================================================================
    // SACRED PREEMPTION CHECK (Lucas Sequence)
    // ========================================================================

    function is_sacred_preemption_point;
        input [31:0] count;
        begin
            is_sacred_preemption_point =
                (count == 32'd2)  ||
                (count == 32'd3)  ||
                (count == 32'd4)  ||
                (count == 32'd7)  ||
                (count == 32'd11) ||
                (count == 32'd18) ||
                (count == 32'd29) ||
                (count == 32'd47) ||
                (count == 32'd76);
        end
    endfunction

    // ========================================================================
    // COUNT ACTIVE TASKS
    // ========================================================================

    always @(*) begin
        active_tasks_reg = 0;
        for (i = 0; i < MAX_TASKS; i = i + 1) begin
            if (task_valid[i] && (task_prio[i] != PRIO_BLOCKED))
                active_tasks_reg = active_tasks_reg + 1;
        end
    end

    // Loop index variable
    integer i;

    assign active_count = active_tasks_reg;

    // ========================================================================
    // FIND NEXT RUNNABLE TASK (Round-Robin)
    // ========================================================================

    reg [LOG2_MAX_TASKS-1:0] scan_ptr;
    reg found_next;
    reg [LOG2_MAX_TASKS-1:0] found_task;

    always @(*) begin
        found_task = next_task_ptr;
        found_next = 1'b0;

        // Search starting from next_task_ptr, wrapping around
        for (i = 0; i < MAX_TASKS; i = i + 1) begin
            idx_temp = (next_task_ptr + i) % MAX_TASKS;
            if (!found_next && task_valid[idx_temp] && (task_prio[idx_temp] != PRIO_BLOCKED)) begin
                found_task = idx_temp[LOG2_MAX_TASKS-1:0];
                found_next = 1'b1;
            end
        end

        scan_ptr = found_task;
    end

    // Temporary index for round-robin search
    reg [LOG2_MAX_TASKS-1:0] idx_temp;

    // ========================================================================
    // STATE REGISTER
    // ========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 32'd0;
            sacred_count <= 32'd0;
            current_task_reg <= {LOG2_MAX_TASKS{1'b0}};
            next_task_ptr <= {LOG2_MAX_TASKS{1'b0}};
            current_slice_remaining <= 16'd0;
            task_switch <= 1'b0;
            preemption_irq <= 1'b0;
            scheduler_idle <= 1'b1;

            // Clear all tasks
            task_valid <= {MAX_TASKS{1'b0}};
            task_priority_ram <= {(MAX_TASKS*2){1'b0}};
            task_time_slice <= {(MAX_TASKS*16){1'b0}};

        end else begin
            // Default signals
            task_switch <= 1'b0;
            preemption_irq <= 1'b0;
            scheduler_idle <= (state == IDLE) || (active_tasks_reg == 0);

            // State transitions
            case (state)
                IDLE: begin
                    if (active_tasks_reg > 0) begin
                        state <= SCHEDULE;
                    end
                end

                SCHEDULE: begin
                    if (found_next) begin
                        current_task_reg <= scan_ptr;
                        current_slice_remaining <= task_time_slice[scan_ptr*16 +: 16];
                        task_switch <= 1'b1;
                        next_task_ptr <= (scan_ptr + 1) % MAX_TASKS;
                        state <= RUNNING;
                    end else begin
                        state <= IDLE;
                    end
                end

                RUNNING: begin
                    cycle_count <= cycle_count + 1;
                    sacred_count <= sacred_count + 1;

                    // Check for preemption conditions
                    if (task_yield ||
                        current_slice_remaining == 16'd0 ||
                        is_sacred_preemption_point(sacred_count + 1)) begin

                        preemption_irq <= 1'b1;
                        state <= PREEMPTING;
                    end

                    // Decrement time slice
                    if (current_slice_remaining != 16'd0)
                        current_slice_remaining <= current_slice_remaining - 1;
                end

                PREEMPTING: begin
                    state <= SCHEDULE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Handle task spawn/kill
            if (task_spawn) begin
                task_valid[task_id] <= 1'b1;
                task_priority_ram[task_id*2 +: 2] <= task_priority;
                task_time_slice[task_id*16 +: 16] <= calculate_time_slice(task_priority);
            end

            if (task_kill && task_valid[task_id]) begin
                task_valid[task_id] <= 1'b0;
                if (current_task_reg == task_id && state == RUNNING) begin
                    state <= PREEMPTING;
                end
            end
        end
    end

    // ========================================================================
    // OUTPUTS
    // ========================================================================

    assign current_task = current_task_reg;
    assign cycle_counter = cycle_count;
    assign sacred_counter = sacred_count;
    assign scheduler_state = state;

    // ========================================================================
    // ASSERTIONS (Formal Verification)
    // ========================================================================

`ifdef FORMAL
    // Verify phi-scaled time slice is >= base
    always @(*) begin
        if (task_priority != PRIO_BLOCKED) begin
            assert (calculate_time_slice(task_priority) >= BASE_CYCLES[15:0] ||
                    calculate_time_slice(task_priority) == 16'd0);
        end
    end

    // Verify preemption at sacred numbers
    always @(posedge clk) begin
        if (rst_n && state == RUNNING && is_sacred_preemption_point(sacred_count)) begin
            assert (preemption_irq);
        end
    end
`endif

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY IDENTITY ASSERTION
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3
// Localparam real PHI = 1.6180339887498948482;
// Localparam real GOLDEN_IDENTITY = PHI * PHI + 1.0 / (PHI * PHI);
// assert(GOLDEN_IDENTITY >= 2.99 && GOLDEN_IDENTITY <= 3.01);

// ═══════════════════════════════════════════════════════════════════════════════
// END OF TERNARY_SCHEDULER
// ═══════════════════════════════════════════════════════════════════════════════
