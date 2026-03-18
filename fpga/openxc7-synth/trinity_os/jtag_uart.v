// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  TRINITY OS — JTAG UART Core v1.0                                           ║
// ║                                                                              ║
// ║  Lightweight JTAG-to-UART bridge for Xilinx 7-series                        ║
// ║  Uses USER1 instruction register for bidirectional data transfer            ║
// ║                                                                              ║
// ║  Architecture:                                                              ║
// ║    Host ──► OpenOCD ──► JTAG TAP ──► USER1 IR ──► TX Data                  ║
// ║    Host ◄── OpenOCD ◄── JTAG TAP ◄── USER1 IR ◄── RX Data                  ║
// ║                                                                              ║
// ║  USER1 Instruction: 0x22 (Xilinx standard)                                  ║
// ║  Data Register: 32 bits (TX[31:16] | RX[15:0])                             ║
// ║                                                                              ║
// ║  Usage:                                                                     ║
// ║    1. OpenOCD writes to DR: tx_data | 0xFFFF                                ║
// ║    2. FPGA reads tx_data, raises tx_valid flag                             ║
// ║    3. FPGA writes rx_data to lower half, clears rx_ready                    ║
// ║    4. OpenOCD reads DR: rx_data | status_flags                              ║
// ╚════════════════════════════════════════════════════════════════════════════╝

`timescale 1ns / 1ps
`default_nettype none

//==============================================================================
// XILINX 7-SERIES BSCAN PRIMITIVE (Built-in JTAG TAP)
//==============================================================================
// This primitive gives access to the FPGA's built-in JTAG TAP
// USER1 instruction code = 0x22 (standard Xilinx)

(* blackbox *)
module BSCAN2 (
    input  wire CAPTURE,
    input  wire DRCK,
    input  wire RESET,
    input  wire RUNTEST,
    input  wire SEL,
    input  wire SHIFT,
    output wire TCK,
    input  wire TDI,
    output wire TMS,
    output wire UPDATE,
    output wire TDO
);

    // For simulation - in real synthesis, Xilinx provides this
    // In Yosys/nextpnr, we'll use a workaround
endmodule

//==============================================================================
// SIMPLIFIED JTAG TAP (For synthesis without Xilinx tools)
//==============================================================================
module JTAG_TAP_Simple (
    input  wire clk,
    input  wire rst_n,

    // JTAG signals (from FPGA pins)
    input  wire tms,
    input  wire tck,
    input  wire tdi,
    output wire tdo,

    // Internal interface
    output reg         tap_select,    // USER1 selected
    output reg         tap_capture,
    output reg         tap_shift,
    output reg         tap_update,
    input  wire [31:0] tap_data_in,
    output reg  [31:0] tap_data_out
);

    //==========================================================================
    // TAP State Machine (simplified)
    //==========================================================================
    // States: Test-Logic-Reset, Run-Test/Idle, Select-DR, Capture-DR,
    //          Shift-DR, Exit1-DR, Pause-DR, Exit2-DR, Update-DR,
    //          Select-IR, Capture-IR, Shift-IR, Exit1-IR, Pause-IR,
    //          Exit2-IR, Update-IR

    localparam S_RESET        = 4'd0;
    localparam S_IDLE         = 4'd1;
    localparam S_SELECT_DR    = 4'd2;
    localparam S_CAPTURE_DR   = 4'd3;
    localparam S_SHIFT_DR     = 4'd4;
    localparam S_EXIT1_DR     = 4'd5;
    localparam S_PAUSE_DR     = 4'd6;
    localparam S_EXIT2_DR     = 4'd7;
    localparam S_UPDATE_DR    = 4'd8;
    localparam S_SELECT_IR    = 4'd9;
    localparam S_CAPTURE_IR   = 4'd10;
    localparam S_SHIFT_IR     = 4'd11;
    localparam S_EXIT1_IR     = 4'd12;
    localparam S_PAUSE_IR     = 4'd13;
    localparam S_EXIT2_IR     = 4'd14;
    localparam S_UPDATE_IR    = 4'd15;

    reg [3:0] state;
    reg [31:0] shift_reg;
    reg [3:0]  bit_count;

    // Instruction register (4 bits for USER codes)
    reg [3:0] ir;
    localparam IR_USER1   = 4'h2;   // USER1 instruction (simplified)
    localparam IR_BYPASS  ='hF;

    // TCK edge detection
    reg tck_d1, tck_rise;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_RESET;
            ir <= IR_BYPASS;
            shift_reg <= 32'd0;
            bit_count <= 4'd0;
            tck_d1 <= 1'b0;
        end else begin
            tck_d1 <= tck;
            tck_rise <= tck & ~tck_d1;

            if (tck_rise) begin
                case (state)
                    S_RESET: begin
                        if (tms)
                            state <= S_RESET;
                        else
                            state <= S_IDLE;
                    end

                    S_IDLE: begin
                        if (tms)
                            state <= S_SELECT_DR;
                    end

                    S_SELECT_DR: begin
                        if (~tms)
                            state <= S_CAPTURE_DR;
                        else
                            state <= S_SELECT_IR;
                    end

                    S_CAPTURE_DR: begin
                        if (~tms)
                            state <= S_SHIFT_DR;
                        else
                            state <= S_EXIT1_DR;
                    end

                    S_SHIFT_DR: begin
                        if (~tms) begin
                            // Shift data
                            shift_reg <= {tdi, shift_reg[31:1]};
                            bit_count <= bit_count + 1;
                        end else begin
                            state <= S_EXIT1_DR;
                        end
                    end

                    S_EXIT1_DR: begin
                        if (~tms)
                            state <= S_PAUSE_DR;
                        else
                            state <= S_UPDATE_DR;
                    end

                    S_PAUSE_DR: begin
                        if (tms)
                            state <= S_EXIT2_DR;
                    end

                    S_EXIT2_DR: begin
                        if (~tms)
                            state <= S_SHIFT_DR;
                        else
                            state <= S_UPDATE_DR;
                    end

                    S_UPDATE_DR: begin
                        if (~tms)
                            state <= S_IDLE;
                        else
                            state <= S_SELECT_DR;
                    end

                    S_SELECT_IR: begin
                        if (~tms)
                            state <= S_CAPTURE_IR;
                        else
                            state <= S_RESET;
                    end

                    S_CAPTURE_IR: begin
                        ir <= 4'd0;  // Capture IR
                        if (~tms)
                            state <= S_SHIFT_IR;
                        else
                            state <= S_EXIT1_IR;
                    end

                    S_SHIFT_IR: begin
                        if (~tms) begin
                            ir <= {tdi, ir[3:1]};
                        end else begin
                            state <= S_EXIT1_IR;
                        end
                    end

                    S_EXIT1_IR: begin
                        if (~tms)
                            state <= S_PAUSE_IR;
                        else
                            state <= S_UPDATE_IR;
                    end

                    S_PAUSE_IR: begin
                        if (tms)
                            state <= S_EXIT2_IR;
                    end

                    S_EXIT2_IR: begin
                        if (~tms)
                            state <= S_SHIFT_IR;
                        else
                            state <= S_UPDATE_IR;
                    end

                    S_UPDATE_IR: begin
                        state <= S_IDLE;
                    end

                    default: state <= S_RESET;
                endcase
            end

            // Update data register
            if (state == S_UPDATE_DR) begin
                tap_data_out <= shift_reg;
            end

            // Capture data register
            if (state == S_CAPTURE_DR) begin
                shift_reg <= tap_data_in;
                bit_count <= 4'd0;
            end
        end
    end

    // Output signals
    assign tdo = (state == S_SHIFT_DR || state == S_SHIFT_IR) ? shift_reg[0] : 1'b0;
    assign tap_select = (ir == IR_USER1);
    assign tap_capture = (state == S_CAPTURE_DR);
    assign tap_shift = (state == S_SHIFT_DR);
    assign tap_update = (state == S_UPDATE_DR);

endmodule

//==============================================================================
// JTAG UART - Main Module
//==============================================================================
module JTAG_UART #(
    parameter CLKS_PER_BIT = 434,  // 115200 baud @ 50MHz
    parameter TX_FIFO_DEPTH = 16,
    parameter RX_FIFO_DEPTH = 16
)(
    input  wire        clk,
    input  wire        rst_n,

    // JTAG signals (connect to FPGA pins)
    input  wire        jtag_tms,
    input  wire        jtag_tck,
    input  wire        jtag_tdi,
    output wire        jtag_tdo,

    // UART interface
    input  wire        uart_rx,
    output wire        uart_tx,

    // Status LEDs
    output wire        led_tx_active,
    output wire        led_rx_active,

    // Debug interface
    output wire [31:0] debug_tap_data,
    output wire        debug_tap_select
);

    //======================================================================
    // TAP Controller
    //======================================================================
    wire        tap_select;
    wire        tap_capture;
    wire        tap_shift;
    wire        tap_update;
    wire [31:0] tap_data_out;
    wire [31:0] tap_data_in;

    // JTAG data format: [31:16] = TX from host, [15:0] = RX to host
    wire [15:0] jtag_tx_data = tap_data_out[31:16];
    wire [15:0] jtag_rx_data = tap_data_in[15:0];

    JTAG_TAP_Simple tap_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tms(jtag_tms),
        .tck(jtag_tck),
        .tdi(jtag_tdi),
        .tdo(jtag_tdo),
        .tap_select(tap_select),
        .tap_data_in(tap_data_in),
        .tap_data_out(tap_data_out)
    );

    assign debug_tap_data = tap_data_out;
    assign debug_tap_select = tap_select;

    //======================================================================
    // TX FIFO (Host → FPGA)
    //======================================================================
    reg [15:0] tx_fifo [0:TX_FIFO_DEPTH-1];
    reg [3:0]  tx_wr_ptr;
    reg [3:0]  tx_rd_ptr;
    reg        tx_full;
    reg        tx_empty;

    wire [15:0] tx_data_out = tx_fifo[tx_rd_ptr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_wr_ptr <= 4'd0;
            tx_rd_ptr <= 4'd0;
            tx_empty <= 1'b1;
        end else begin
            // Write from JTAG
            if (tap_select && tap_update && jtag_tx_data != 16'hFFFF) begin
                if (!tx_full) begin
                    tx_fifo[tx_wr_ptr] <= jtag_tx_data;
                    tx_wr_ptr <= tx_wr_ptr + 1;
                    tx_empty <= 1'b0;
                end
            end

            // Read to UART transmitter
            if (uart_tx_start && !tx_empty) begin
                tx_rd_ptr <= tx_rd_ptr + 1;
                if (tx_rd_ptr + 1 == tx_wr_ptr)
                    tx_empty <= 1'b1;
            end
        end
    end

    assign tx_full = (tx_wr_ptr == tx_rd_ptr) && !tx_empty;

    //======================================================================
    // RX FIFO (FPGA → Host)
    //======================================================================
    reg [15:0] rx_fifo [0:RX_FIFO_DEPTH-1];
    reg [3:0]  rx_wr_ptr;
    reg [3:0]  rx_rd_ptr;
    reg        rx_full;
    reg        rx_empty;

    wire [15:0] rx_data_in = {8'd0, uart_rx_data};
    wire [15:0] rx_data_out = rx_fifo[rx_rd_ptr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_wr_ptr <= 4'd0;
            rx_rd_ptr <= 4'd0;
            rx_empty <= 1'b1;
        end else begin
            // Write from UART receiver
            if (uart_rx_valid && !rx_full) begin
                rx_fifo[rx_wr_ptr] <= rx_data_in;
                rx_wr_ptr <= rx_wr_ptr + 1;
                rx_empty <= 1'b0;
            end

            // Read to JTAG (host reads on SHIFT)
            if (tap_select && tap_capture && !rx_empty) begin
                rx_rd_ptr <= rx_rd_ptr + 1;
                if (rx_rd_ptr + 1 == rx_wr_ptr)
                    rx_empty <= 1'b1;
            end
        end
    end

    assign rx_full = (rx_wr_ptr == rx_rd_ptr) && !rx_empty;

    //======================================================================
    // UART Transmitter
    //======================================================================
    reg        uart_tx_start;
    reg [7:0]  uart_tx_data;
    reg        uart_tx_busy;
    reg [15:0] uart_tx_baud_counter;
    reg [2:0]  uart_tx_bit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx_busy <= 1'b0;
            uart_tx_baud_counter <= 16'd0;
            uart_tx_bit <= 3'd0;
            uart_tx_start <= 1'b0;
        end else begin
            uart_tx_start <= 1'b0;

            if (!uart_tx_busy && !tx_empty) begin
                uart_tx_data <= tx_data_out[7:0];
                uart_tx_busy <= 1'b1;
                uart_tx_bit <= 3'd0;
                uart_tx_baud_counter <= 16'd0;
                uart_tx_start <= 1'b1;
            end else if (uart_tx_busy) begin
                if (uart_tx_baud_counter == CLKS_PER_BIT - 1) begin
                    uart_tx_baud_counter <= 16'd0;
                    uart_tx_bit <= uart_tx_bit + 1;
                    if (uart_tx_bit == 3'd8) begin  // Done
                        uart_tx_busy <= 1'b0;
                    end
                end else begin
                    uart_tx_baud_counter <= uart_tx_baud_counter + 1;
                end
            end
        end
    end

    // UART TX bit output
    reg uart_tx_bit_out;
    always @(*) begin
        if (!uart_tx_busy)
            uart_tx_bit_out = 1'b1;  // Idle
        else if (uart_tx_bit == 0)
            uart_tx_bit_out = 1'b0;  // Start bit
        else if (uart_tx_bit >= 1 && uart_tx_bit <= 8)
            uart_tx_bit_out = uart_tx_data[uart_tx_bit-1];
        else
            uart_tx_bit_out = 1'b1;  // Stop bit
    end

    assign uart_tx = uart_tx_bit_out;

    //======================================================================
    // UART Receiver
    //======================================================================
    reg [7:0]  uart_rx_data;
    reg        uart_rx_valid;
    reg [15:0] uart_rx_baud_counter;
    reg [2:0]  uart_rx_bit;
    reg [7:0]  uart_rx_shift;
    reg        uart_rx_sync1, uart_rx_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_rx_valid <= 1'b0;
            uart_rx_baud_counter <= 16'd0;
            uart_rx_bit <= 3'd0;
            uart_rx_sync1 <= 1'b1;
            uart_rx_sync2 <= 1'b1;
        end else begin
            uart_rx_valid <= 1'b0;

            // Synchronize input
            uart_rx_sync1 <= uart_rx;
            uart_rx_sync2 <= uart_rx_sync1;

            // Start bit detection
            if (uart_rx_sync2 && !uart_rx_sync1) begin
                uart_rx_baud_counter <= 16'd0;
                uart_rx_bit <= 3'd0;
            end else if (uart_rx_bit > 0 || uart_rx_baud_counter > 0) begin
                if (uart_rx_baud_counter == CLKS_PER_BIT/2 - 1) begin
                    uart_rx_baud_counter <= 16'd0;

                    if (uart_rx_bit == 0) begin
                        // Verify start bit
                        if (!uart_rx_sync1)
                            uart_rx_bit <= uart_rx_bit + 1;
                    end else if (uart_rx_bit >= 1 && uart_rx_bit <= 8) begin
                        uart_rx_shift[uart_rx_bit-1] <= uart_rx_sync1;
                        uart_rx_bit <= uart_rx_bit + 1;
                    end else begin
                        // Stop bit - data ready
                        uart_rx_data <= uart_rx_shift;
                        uart_rx_valid <= 1'b1;
                        uart_rx_bit <= 3'd0;
                    end
                end else begin
                    uart_rx_baud_counter <= uart_rx_baud_counter + 1;
                end
            end
        end
    end

    //======================================================================
    // Status LEDs
    //======================================================================
    assign led_tx_active = uart_tx_busy;
    assign led_rx_active = uart_rx_valid;

endmodule

//==============================================================================
// TRINITY TOP WITH JTAG UART
//==============================================================================
module trinity_jtag_uart_top (
    input  wire clk,          // 50 MHz (U22)
    input  wire rst,          // Reset button (P16)

    // JTAG (connects to JTAG cable)
    input  wire jtag_tms,
    input  wire jtag_tck,
    input  wire jtag_tdi,
    output wire jtag_tdo,

    // UART (loopback or external)
    input  wire uart_rx,
    output wire uart_tx,

    // Status LEDs
    output wire led_tx,
    output wire led_rx,
    output wire led_jtag_active
);

    // Reset synchronization
    reg [2:0] rst_sync;
    wire rst_n = ~rst_sync[2];

    always @(posedge clk) begin
        rst_sync <= {rst_sync[1:0], rst};
    end

    // JTAG UART instance
    wire [31:0] debug_tap_data;
    wire        debug_tap_select;

    JTAG_UART jtag_uart_inst (
        .clk(clk),
        .rst_n(rst_n),
        .jtag_tms(jtag_tms),
        .jtag_tck(jtag_tck),
        .jtag_tdi(jtag_tdi),
        .jtag_tdo(jtag_tdo),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .led_tx_active(led_tx),
        .led_rx_active(led_rx),
        .debug_tap_data(debug_tap_data),
        .debug_tap_select(debug_tap_select)
    );

    // JTAG active LED
    assign led_jtag_active = debug_tap_select;

endmodule

// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  END OF JTAG UART MODULE                                                     ║
// ╚════════════════════════════════════════════════════════════════════════════╝
