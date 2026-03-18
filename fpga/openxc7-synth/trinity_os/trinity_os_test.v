// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY OS — Test Wrapper for Synthesis
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module trinity_os_test (
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] debug_state,
    output wire        cpu_irq,
    output wire [3:0]  active_tasks
);

    // Mock UART signals
    wire [31:0] uart_rx_data;
    wire        uart_rx_valid;
    wire [31:0] uart_tx_data;
    wire        uart_tx_valid;
    wire        uart_tx_ready;

    assign uart_rx_data = 32'd0;
    assign uart_rx_valid = 1'b0;

    // Instantiate OS top (with stub uart)
    trinity_os_top os_inst (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx_data(uart_rx_data),
        .uart_rx_valid(uart_rx_valid),
        .uart_tx_data(uart_tx_data),
        .uart_tx_valid(uart_tx_valid),
        .uart_tx_ready(uart_tx_ready),
        .cpu_interrupt(cpu_irq),
        .irq_vector(),
        .scheduler_state(debug_state[3:0]),
        .active_task_count(active_tasks),
        .cycle_counter(),
        .sacred_counter(),
        .irq_count(),
        .current_task_id(),
        .system_idle()
    );

endmodule
