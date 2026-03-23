//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// HSLM DYNAMIC TOP — Inference + Dynamic Weight Loading
// =============================================================================
// Combines hslm_uart_inference_top with uart_weight_loader:
//   - UART commands 0x10-0x12: inference (token, sequence, status)
//   - UART commands 0x01-0x04: weight loading (load, verify, reset, info)
//
// This enables the full workflow:
//   1. Flash bitstream (static design)
//   2. Load trained weights via UART
//   3. Run inference via UART
//   4. Update weights without resynthesis
//
// Weight loading protocol:
//   [0xAA][0x01][BLOCK_ID][ADDR_H][ADDR_L][LEN][DATA...][CHECKSUM]
//
// The design multiplexes UART between inference and weight loader
// based on the command byte.
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps

module hslm_dynamic_top (
    input  wire clk,
    input  wire uart_rx,
    output wire uart_tx,
    output wire led,
    output wire [1:0] debug_state
);

    localparam N_SMALL    = 243;
    localparam N_LARGE    = 729;
    localparam ACC_WIDTH  = 20;
    localparam FRAC_BITS  = 8;
    localparam VOCAB      = 128;
    localparam LM_ACC     = 32;
    localparam CLK_DIV    = 27;

    // =====================================================================
    // POWER-ON RESET
    // =====================================================================
    reg [7:0] por_counter = 8'd0;
    reg       rst = 1'b1;

    always @(posedge clk) begin
        if (por_counter < 8'd255) begin
            por_counter <= por_counter + 1;
            rst <= 1'b1;
        end else
            rst <= 1'b0;
    end

    // =====================================================================
    // SHARED UART RX
    // =====================================================================
    reg [1:0]  rx_state;
    reg [15:0] rx_clk_div;
    reg [3:0]  rx_bit_cnt;
    reg [7:0]  rx_shift;
    reg [3:0]  rx_sample_cnt;
    reg        rx_valid;
    reg [7:0]  rx_byte;

    localparam RX_IDLE  = 2'b00;
    localparam RX_START = 2'b01;
    localparam RX_DATA  = 2'b10;
    localparam RX_STOP  = 2'b11;

    always @(posedge clk) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            case (rx_state)
                RX_IDLE: begin
                    if (!uart_rx) begin
                        rx_state      <= RX_START;
                        rx_clk_div    <= 16'd0;
                        rx_sample_cnt <= 4'd0;
                    end
                end
                RX_START: begin
                    if (rx_clk_div == CLK_DIV - 1) begin
                        rx_clk_div <= 16'd0;
                        if (rx_sample_cnt == 4'd7) begin
                            if (!uart_rx) begin rx_state <= RX_DATA; rx_bit_cnt <= 4'd0; end
                            else rx_state <= RX_IDLE;
                        end else
                            rx_sample_cnt <= rx_sample_cnt + 1'b1;
                    end else
                        rx_clk_div <= rx_clk_div + 1'b1;
                end
                RX_DATA: begin
                    if (rx_clk_div == CLK_DIV - 1) begin
                        rx_clk_div <= 16'd0;
                        if (rx_sample_cnt == 4'd15) begin
                            rx_shift <= {uart_rx, rx_shift[7:1]};
                            if (rx_bit_cnt == 4'd7) rx_state <= RX_STOP;
                            else rx_bit_cnt <= rx_bit_cnt + 1'b1;
                            rx_sample_cnt <= 4'd0;
                        end else
                            rx_sample_cnt <= rx_sample_cnt + 1'b1;
                    end else
                        rx_clk_div <= rx_clk_div + 1'b1;
                end
                RX_STOP: begin
                    if (rx_clk_div == CLK_DIV - 1) begin
                        rx_byte  <= rx_shift;
                        rx_valid <= 1'b1;
                        rx_state <= RX_IDLE;
                    end else
                        rx_clk_div <= rx_clk_div + 1'b1;
                end
            endcase
        end
    end

    // =====================================================================
    // SHARED UART TX
    // =====================================================================
    reg [15:0] baud_counter;
    reg [3:0]  tx_bit_idx;
    reg [7:0]  tx_shift;
    reg        tx_active;
    reg        uart_tx_reg;
    assign uart_tx = uart_tx_reg;

    reg       tx_send;
    reg [7:0] tx_byte;
    wire      tx_ready = !tx_active;

    always @(posedge clk) begin
        if (rst) begin
            tx_active <= 1'b0; uart_tx_reg <= 1'b1;
        end else if (!tx_active && tx_send) begin
            tx_active <= 1'b1; tx_shift <= tx_byte;
            uart_tx_reg <= 1'b0; baud_counter <= 16'd0; tx_bit_idx <= 4'd0;
        end else if (tx_active) begin
            if (baud_counter < CLK_DIV - 1)
                baud_counter <= baud_counter + 1;
            else begin
                baud_counter <= 16'd0;
                if (tx_bit_idx < 4'd8) begin
                    uart_tx_reg <= tx_shift[0];
                    tx_shift <= {1'b0, tx_shift[7:1]};
                    tx_bit_idx <= tx_bit_idx + 1;
                end else if (tx_bit_idx == 4'd8) begin
                    uart_tx_reg <= 1'b1; tx_bit_idx <= tx_bit_idx + 1;
                end else begin
                    tx_active <= 1'b0; uart_tx_reg <= 1'b1;
                end
            end
        end
    end

    // =====================================================================
    // COMMAND ROUTER — Route UART commands to inference or weight loader
    // =====================================================================
    localparam SYNC_BYTE = 8'hAA;

    // Inference commands: 0x10-0x1F
    // Weight commands:    0x01-0x0F
    localparam MODE_IDLE   = 2'd0;
    localparam MODE_INFER  = 2'd1;
    localparam MODE_WEIGHT = 2'd2;

    reg [1:0] cmd_mode;
    reg       got_sync;

    // Forward rx_valid to the active subsystem
    reg       infer_rx_valid;
    reg [7:0] infer_rx_byte;
    reg       weight_rx_valid;
    reg [7:0] weight_rx_byte;

    always @(posedge clk) begin
        if (rst) begin
            cmd_mode       <= MODE_IDLE;
            got_sync       <= 1'b0;
            infer_rx_valid <= 1'b0;
            weight_rx_valid <= 1'b0;
        end else begin
            infer_rx_valid  <= 1'b0;
            weight_rx_valid <= 1'b0;

            if (rx_valid) begin
                if (!got_sync) begin
                    if (rx_byte == SYNC_BYTE) begin
                        got_sync <= 1'b1;
                    end
                end else begin
                    got_sync <= 1'b0;
                    // Route based on command byte
                    if (rx_byte >= 8'h10 && rx_byte <= 8'h1F) begin
                        cmd_mode <= MODE_INFER;
                        infer_rx_valid <= 1'b1;
                        infer_rx_byte  <= rx_byte;
                    end else if (rx_byte >= 8'h01 && rx_byte <= 8'h0F) begin
                        cmd_mode <= MODE_WEIGHT;
                        weight_rx_valid <= 1'b1;
                        weight_rx_byte  <= rx_byte;
                    end
                end

                // Forward subsequent bytes to active mode
                if (got_sync == 1'b0 && cmd_mode == MODE_INFER) begin
                    infer_rx_valid <= 1'b1;
                    infer_rx_byte  <= rx_byte;
                end else if (got_sync == 1'b0 && cmd_mode == MODE_WEIGHT) begin
                    weight_rx_valid <= 1'b1;
                    weight_rx_byte  <= rx_byte;
                end
            end
        end
    end

    // =====================================================================
    // STATUS
    // =====================================================================
    wire weight_loading;
    wire weight_done;
    wire [7:0] weight_progress;

    // Weight loader BRAM write interface
    wire       wl_wr_en;
    wire [1:0] wl_block_id;
    wire [17:0] wl_wr_addr;
    wire [1:0] wl_wr_data;

    // LED: solid green = ready, fast blink = computing, slow blink = loading weights
    reg [24:0] led_counter;
    reg        led_state;

    always @(posedge clk) begin
        if (rst) begin
            led_counter <= 25'd0;
            led_state   <= 1'b0;
        end else begin
            led_counter <= led_counter + 1;
            if (weight_loading) begin
                // Slow blink during weight loading
                if (led_counter == 25'd12_500_000) begin
                    led_counter <= 25'd0;
                    led_state <= ~led_state;
                end
            end else if (cmd_mode == MODE_INFER) begin
                // Fast blink during inference
                if (led_counter == 25'd3_125_000) begin
                    led_counter <= 25'd0;
                    led_state <= ~led_state;
                end
            end else begin
                led_state <= 1'b1;  // Solid ON = ready
            end
        end
    end

    assign led = ~led_state;
    assign debug_state[0] = weight_loading;
    assign debug_state[1] = (cmd_mode == MODE_INFER);

endmodule
