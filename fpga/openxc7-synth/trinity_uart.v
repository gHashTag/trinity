//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY UART — Simple UART for TRINITY CORE V2
// ═══════════════════════════════════════════════════════════════════════════════
//
// Simple 8-N-1 UART transmitter and receiver
// - Baud rate: 115200 (default, configurable)
// - Clock: 50 MHz
// - Interface: Memory-mapped registers
//
// ═══════════════════════════════════════════════════════════════════════════════

module trinity_uart (
    input  wire        clk,
    input  wire        rst_n,

    // UART interface
    output reg         uart_tx,
    input  wire        uart_rx,

    // Memory-mapped interface
    input  wire [11:0]  addr,
    input  wire        we,
    input  wire        re,
    input  wire [31:0]  wdata,
    output reg  [31:0]  rdata,

    // Interrupt output
    output wire        rx_irq  // RX data available interrupt
);

    //==========================================================================
    // Parameters
    //==========================================================================
    // Default divisor for 115200 baud @ 50MHz
    // divisor = clk_freq / (baud_rate * 16)
    // 50,000,000 / (115200 * 16) ≈ 27
    localparam DEFAULT_DIVISOR = 12'd27;

    //==========================================================================
    // Registers
    //==========================================================================
    reg [11:0] divisor_reg;
    reg [7:0]  tx_data;
    reg [7:0]  rx_data;
    reg        tx_busy;
    reg        rx_valid;

    // Status register bits
    // bit 0: TX ready (1 = ready to transmit)
    // bit 1: RX available (1 = data received)
    wire status_tx_ready = ~tx_busy;
    wire status_rx_avail = rx_valid;

    //==========================================================================
    // TX State Machine
    //==========================================================================
    localparam TX_IDLE  = 2'd0;
    localparam TX_START = 2'd1;
    localparam TX_DATA  = 2'd2;
    localparam TX_STOP  = 2'd3;

    reg [1:0]  tx_state;
    reg [3:0]  tx_bit_cnt;
    reg [15:0] tx_divcnt;
    reg [7:0]  tx_shift;

    // TX baud tick generator (oversampling by 16)
    wire tx_baud_tick;
    assign tx_baud_tick = (tx_divcnt == divisor_reg);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx_busy <= 1'b0;
            uart_tx <= 1'b1;
            tx_divcnt <= 16'd0;
            tx_bit_cnt <= 4'd0;
            tx_shift <= 8'd0;
        end else begin
            tx_divcnt <= tx_divcnt + 1'd1;

            case (tx_state)
                TX_IDLE: begin
                    tx_busy <= 1'b0;
                    uart_tx <= 1'b1;
                    tx_divcnt <= 16'd0;
                    if (we && addr[4:2] == 3'b001) begin  // TX register write
                        tx_shift <= wdata[7:0];
                        tx_state <= TX_START;
                        tx_busy <= 1'b1;
                        tx_divcnt <= 16'd0;
                    end
                end

                TX_START: begin
                    uart_tx <= 1'b0;  // Start bit
                    if (tx_baud_tick) begin
                        tx_divcnt <= 16'd0;
                        tx_state <= TX_DATA;
                        tx_bit_cnt <= 4'd0;
                    end
                end

                TX_DATA: begin
                    uart_tx <= tx_shift[0];
                    if (tx_baud_tick) begin
                        tx_divcnt <= 16'd0;
                        tx_shift <= {1'b1, tx_shift[7:1]};  // Shift
                        if (tx_bit_cnt == 4'd7)
                            tx_state <= TX_STOP;
                        else
                            tx_bit_cnt <= tx_bit_cnt + 1'd1;
                    end
                end

                TX_STOP: begin
                    uart_tx <= 1'b1;  // Stop bit
                    if (tx_baud_tick) begin
                        tx_state <= TX_IDLE;
                    end
                end
            endcase
        end
    end

    //==========================================================================
    // RX State Machine
    //==========================================================================
    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA  = 2'd2;
    localparam RX_STOP  = 2'd3;

    reg [1:0]  rx_state;
    reg [3:0]  rx_bit_cnt;
    reg [15:0] rx_divcnt;
    reg [7:0]  rx_shift;

    // RX baud tick (oversampling by 16)
    wire rx_baud_tick;
    assign rx_baud_tick = (rx_divcnt == divisor_reg);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            rx_valid <= 1'b0;
            rx_divcnt <= 16'd0;
            rx_bit_cnt <= 4'd0;
            rx_shift <= 8'd0;
        end else begin
            // Read clears RX valid
            if (re && addr[4:2] == 3'b010)
                rx_valid <= 1'b0;

            rx_divcnt <= rx_divcnt + 1'd1;

            case (rx_state)
                RX_IDLE: begin
                    if (!uart_rx) begin  // Start bit detected
                        rx_divcnt <= 16'd0;
                        // Sample at middle of start bit (divisor/2)
                        if (rx_divcnt == (divisor_reg >> 1))
                            rx_state <= RX_START;
                    end
                end

                RX_START: begin
                    if (rx_baud_tick) begin
                        rx_divcnt <= 16'd0;
                        if (!uart_rx) begin  // Verify start bit
                            rx_state <= RX_DATA;
                            rx_bit_cnt <= 4'd0;
                        end else
                            rx_state <= RX_IDLE;
                    end
                end

                RX_DATA: begin
                    if (rx_baud_tick) begin
                        rx_divcnt <= 16'd0;
                        rx_shift <= {uart_rx, rx_shift[7:1]};
                        if (rx_bit_cnt == 4'd7)
                            rx_state <= RX_STOP;
                        else
                            rx_bit_cnt <= rx_bit_cnt + 1'd1;
                    end
                end

                RX_STOP: begin
                    if (rx_baud_tick) begin
                        if (uart_rx) begin  // Valid stop bit
                            rx_data <= rx_shift;
                            rx_valid <= 1'b1;
                        end
                        rx_state <= RX_IDLE;
                    end
                end
            endcase
        end
    end

    //==========================================================================
    // Memory-Mapped Register Interface
    //==========================================================================
    // Address map:
    // 0x200: DIVISOR (RW) - Baud rate divisor
    // 0x204: TX_DATA (W)  - Transmit data
    // 0x208: RX_DATA (R)  - Receive data
    // 0x20C: STATUS (R)   - Status register

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            divisor_reg <= DEFAULT_DIVISOR;
            rdata <= 32'd0;
        end else begin
            rdata <= 32'd0;

            // Read operations
            if (re) begin
                case (addr[4:2])
                    3'b000: rdata <= {20'd0, divisor_reg};  // DIVISOR
                    3'b010: rdata <= {24'd0, rx_data};     // RX_DATA
                    3'b011: rdata <= {30'd0, status_rx_avail, status_tx_ready};  // STATUS
                endcase
            end

            // Write operations
            if (we) begin
                case (addr[4:2])
                    3'b000: divisor_reg <= wdata[11:0];  // DIVISOR
                    // TX_DATA is handled by TX state machine
                    // RX_DATA and STATUS are read-only
                endcase
            end
        end
    end

    //==========================================================================
    // Interrupt Output
    //==========================================================================
    assign rx_irq = rx_valid;

endmodule
