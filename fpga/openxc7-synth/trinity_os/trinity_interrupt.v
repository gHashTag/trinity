// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY OS — Interrupt Controller v1.0.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Trit-Priority Interrupt Controller for TRINITY OS
// Golden Identity: φ² + 1/φ² = 3
//
// Interrupt Sources (8):
//   0: UART_RX         - UART data received
//   1: UART_TX         - UART transmit complete
//   2: VSA_COMPLETE    - VSA operation finished
//   3: TQNN_COMPLETE   - TQNN layer inference done
//   4: TIMER           - System timer tick
//   5: YIELD           - Task yield request
//   6: FAULT           - Memory/execution fault
//   7: SPARE           - Reserved for expansion
//
// Priority Encoding (2-bit trits):
//   00 = BLOCKED (-1)  - Interrupt disabled
//   01 = NORMAL  ( 0)  - Standard priority
//   10 = HIGH    (+1)  - High priority (preempt normal)
//   11 = CRITICAL(?1)  - Highest priority
//
// Author: TRINITY OS Team
// Part: TRINITY OS Phase 1 - Kernel Foundation
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module trinity_interrupt #(
    parameter NUM_SOURCES = 8,
    parameter LOG2_NUM_SOURCES = 3
)(
    input  wire                        clk,
    input  wire                        rst_n,

    // Interrupt request inputs (edge-sensitive)
    input  wire [NUM_SOURCES-1:0]      irq_request,
    output wire [NUM_SOURCES-1:0]      irq_ack,

    // Priority configuration (2 bits per source)
    input  wire [NUM_SOURCES*2-1:0]    irq_priority,  // 00=blocked, 01=normal, 10=high, 11=critical
    input  wire                        priority_we,
    input  wire [LOG2_NUM_SOURCES-1:0] priority_addr,
    input  wire [1:0]                  priority_data,

    // Enable mask (1 bit per source)
    input  wire [NUM_SOURCES-1:0]      irq_enable,
    input  wire                        enable_we,
    input  wire [LOG2_NUM_SOURCES-1:0] enable_addr,
    input  wire                        enable_data,

    // Interrupt output
    output reg                         cpu_interrupt,
    output wire [LOG2_NUM_SOURCES-1:0] irq_vector,      // Highest priority pending IRQ
    output wire [7:0]                  irq_count,       // Number of pending IRQs

    // Status
    output wire [NUM_SOURCES-1:0]      irq_pending,
    output wire [NUM_SOURCES-1:0]      irq_served,
    output wire [31:0]                 irq_total_count
);

    // ========================================================================
    // PRIORITY ENCODING
    // ========================================================================

    localparam [1:0] PRIO_BLOCKED  = 2'b00;
    localparam [1:0] PRIO_NORMAL   = 2'b01;
    localparam [1:0] PRIO_HIGH     = 2'b10;
    localparam [1:0] PRIO_CRITICAL = 2'b11;

    // ========================================================================
    // INTERNAL REGISTERS
    // ========================================================================

    // Priority RAM (2 bits per source)
    reg [NUM_SOURCES*2-1:0] priority_reg;

    // Enable mask
    reg [NUM_SOURCES-1:0] enable_reg;

    // Pending interrupts (edge capture)
    reg [NUM_SOURCES-1:0] pending_reg;
    reg [NUM_SOURCES-1:0] irq_request_d1;

    // Served interrupts (history)
    reg [NUM_SOURCES-1:0] served_reg;

    // Total interrupt counter
    reg [31:0] total_count;

    // Priority access
    wire [1:0] irq_prio [NUM_SOURCES-1:0];
    genvar s;
    generate
        for (s = 0; s < NUM_SOURCES; s = s + 1) begin : prio_array
            assign irq_prio[s] = priority_reg[s*2 +: 2];
        end
    endgenerate

    // ========================================================================
    // EDGE DETECTION AND PENDING CAPTURE
    // ========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_request_d1 <= {NUM_SOURCES{1'b0}};
            pending_reg <= {NUM_SOURCES{1'b0}};
        end else begin
            irq_request_d1 <= irq_request;

            // Capture rising edges
            pending_reg <= pending_reg |
                (irq_request & ~irq_request_d1 & enable_reg);
        end
    end

    // ========================================================================
    // PRIORITY ENCODER (Find highest priority pending interrupt)
    // ========================================================================

    reg [LOG2_NUM_SOURCES-1:0] highest_irq;
    reg [1:0] highest_prio;
    reg found_pending;
    integer k;

    always @(*) begin
        highest_irq = {LOG2_NUM_SOURCES{1'b0}};
        highest_prio = PRIO_NORMAL;
        found_pending = 1'b0;

        // Search from highest source number to lowest (higher number = higher priority)
        for (k = NUM_SOURCES - 1; k >= 0; k = k - 1) begin
            if (pending_reg[k] && irq_prio[k] != PRIO_BLOCKED) begin
                if (!found_pending || irq_prio[k] > highest_prio) begin
                    highest_irq = k[LOG2_NUM_SOURCES-1:0];
                    highest_prio = irq_prio[k];
                    found_pending = 1'b1;
                end
            end
        end
    end

    assign irq_vector = found_pending ? highest_irq : {LOG2_NUM_SOURCES{1'b0}};

    // ========================================================================
    // INTERRUPT OUTPUT LOGIC
    // ========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_interrupt <= 1'b0;
            served_reg <= {NUM_SOURCES{1'b0}};
            total_count <= 32'd0;
        end else begin
            // Set interrupt output if any pending and not blocked
            if (found_pending) begin
                cpu_interrupt <= 1'b1;
            end else begin
                cpu_interrupt <= 1'b0;
            end

            // Acknowledge interrupt (clear pending)
            if (cpu_interrupt && found_pending) begin
                pending_reg[highest_irq] <= 1'b0;
                served_reg[highest_irq] <= 1'b1;
                total_count <= total_count + 1;
            end
        end
    end

    // ========================================================================
    // ACKNOWLEDGE OUTPUTS
    // ========================================================================

    assign irq_ack = served_reg & pending_reg;

    // ========================================================================
    // CONFIGURATION REGISTERS
    // ========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            priority_reg <= {(NUM_SOURCES*2){PRIO_NORMAL}};
            enable_reg <= {NUM_SOURCES{1'b0}};
        end else begin
            // Priority write
            if (priority_we) begin
                priority_reg[priority_addr*2 +: 2] <= priority_data;
            end

            // Enable write
            if (enable_we) begin
                enable_reg[enable_addr] <= enable_data;
            end
        end
    end

    // ========================================================================
    // STATUS OUTPUTS
    // ========================================================================

    assign irq_pending = pending_reg;
    assign irq_served = served_reg;

    // Count pending interrupts
    reg [7:0] pending_count;
    integer m;
    always @(*) begin
        pending_count = 0;
        for (m = 0; m < NUM_SOURCES; m = m + 1) begin
            if (pending_reg[m])
                pending_count = pending_count + 1;
        end
    end

    assign irq_count = pending_count;
    assign irq_total_count = total_count;

    // ========================================================================
    // INTERRUPT SOURCE DEFINITIONS
    // ========================================================================

    // Source 0: UART_RX
    wire uart_rx_irq = irq_request[0];

    // Source 1: UART_TX
    wire uart_tx_irq = irq_request[1];

    // Source 2: VSA_COMPLETE
    wire vsa_complete_irq = irq_request[2];

    // Source 3: TQNN_COMPLETE
    wire tqnn_complete_irq = irq_request[3];

    // Source 4: TIMER
    wire timer_irq = irq_request[4];

    // Source 5: YIELD
    wire yield_irq = irq_request[5];

    // Source 6: FAULT
    wire fault_irq = irq_request[6];

    // Source 7: SPARE
    wire spare_irq = irq_request[7];

    // ========================================================================
    // FORMAL PROPERTIES
    // ========================================================================

`ifdef FORMAL
    // If interrupt is output, there must be a pending interrupt
    always @(posedge clk) begin
        if (rst_n && cpu_interrupt)
            assert (|pending_reg);
    end

    // Critical interrupts always preempt normal
    always @(*) begin
        if (pending_reg[7] && irq_prio[7] == PRIO_CRITICAL)
            assert (irq_vector == 3'd7);
    end
`endif

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY IDENTITY: φ² + 1/φ² = 3
// Interrupt Sources: 8 = 2³
// Priority Levels: 4 = 2² (ternary +1 extended)
// Total States: 8 × 4 = 32 = 2⁵
// ═══════════════════════════════════════════════════════════════════════════════
