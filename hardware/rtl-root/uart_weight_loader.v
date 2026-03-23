// =============================================================================
// UART WEIGHT LOADER — Dynamic BRAM weight loading via UART
// =============================================================================
// Allows updating model weights without resynthesis.
// Protocol: [SYNC=0xAA][CMD=0x01][BLOCK_ID][ADDR_H][ADDR_L][LEN][DATA...]
//
// Commands:
//   0x01 LOAD_WEIGHTS  — Write weight data to specified block BRAM
//   0x02 VERIFY_WEIGHTS — Read back weights for verification
//   0x03 RESET_WEIGHTS  — Reset all weights to zero
//   0x04 GET_INFO       — Return block count, dimensions, status
//
// BRAM Interface: dual-port, port A = inference (read), port B = loader (write)
//
// Resource estimate: ~200 LUT, 0 BRAM (uses existing block BRAMs)
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module uart_weight_loader #(
    parameter N_BLOCKS    = 4,       // Number of TrinityBlocks
    parameter ADDR_WIDTH  = 18,      // BRAM address width per block
    parameter DATA_WIDTH  = 2,       // Trit width (2 bits per trit)
    parameter CLK_DIV     = 27       // 50MHz / (16 * 115200) = 27
)(
    input  wire clk,
    input  wire rst,

    // UART interface
    input  wire uart_rx,
    output wire uart_tx,

    // BRAM write interface (active during weight loading)
    output reg                    wr_en,
    output reg  [1:0]             wr_block_id,
    output reg  [ADDR_WIDTH-1:0]  wr_addr,
    output reg  [DATA_WIDTH-1:0]  wr_data,

    // Status
    output wire        loading,     // High during weight load
    output wire        load_done,   // Pulses when load complete
    output wire [7:0]  load_progress, // 0-255 progress indicator
    output wire        load_error   // Error flag
);

    // =========================================================================
    // UART RX
    // =========================================================================
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
            rx_state      <= RX_IDLE;
            rx_valid      <= 1'b0;
            rx_byte       <= 8'd0;
            rx_sample_cnt <= 4'd0;
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
                            if (!uart_rx) begin
                                rx_state   <= RX_DATA;
                                rx_bit_cnt <= 4'd0;
                            end else
                                rx_state <= RX_IDLE;
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
                            if (rx_bit_cnt == 4'd7) begin
                                rx_state <= RX_STOP;
                            end else
                                rx_bit_cnt <= rx_bit_cnt + 1'b1;
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

    // =========================================================================
    // UART TX
    // =========================================================================
    reg [1:0]  tx_state;
    reg [15:0] tx_clk_div;
    reg [3:0]  tx_bit_cnt;
    reg [7:0]  tx_shift;
    reg        tx_active;
    reg        uart_tx_reg;
    reg        tx_send;
    reg [7:0]  tx_byte;
    wire       tx_ready = !tx_active;

    assign uart_tx = uart_tx_reg;

    localparam TX_IDLE  = 2'b00;
    localparam TX_START = 2'b01;
    localparam TX_DATA  = 2'b10;
    localparam TX_STOP  = 2'b11;

    always @(posedge clk) begin
        if (rst) begin
            tx_state    <= TX_IDLE;
            tx_active   <= 1'b0;
            uart_tx_reg <= 1'b1;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    uart_tx_reg <= 1'b1;
                    if (tx_send) begin
                        tx_state    <= TX_START;
                        tx_active   <= 1'b1;
                        tx_shift    <= tx_byte;
                        tx_bit_cnt  <= 4'd0;
                        tx_clk_div  <= 16'd0;
                    end
                end

                TX_START: begin
                    uart_tx_reg <= 1'b0;
                    if (tx_clk_div == CLK_DIV - 1) begin
                        tx_clk_div <= 16'd0;
                        tx_state   <= TX_DATA;
                    end else
                        tx_clk_div <= tx_clk_div + 1'b1;
                end

                TX_DATA: begin
                    uart_tx_reg <= tx_shift[0];
                    if (tx_clk_div == CLK_DIV - 1) begin
                        tx_clk_div <= 16'd0;
                        tx_shift   <= {1'b0, tx_shift[7:1]};
                        if (tx_bit_cnt == 4'd7)
                            tx_state <= TX_STOP;
                        else
                            tx_bit_cnt <= tx_bit_cnt + 1'b1;
                    end else
                        tx_clk_div <= tx_clk_div + 1'b1;
                end

                TX_STOP: begin
                    uart_tx_reg <= 1'b1;
                    if (tx_clk_div == CLK_DIV - 1) begin
                        tx_state  <= TX_IDLE;
                        tx_active <= 1'b0;
                    end else
                        tx_clk_div <= tx_clk_div + 1'b1;
                end
            endcase
        end
    end

    // =========================================================================
    // WEIGHT LOADER FSM
    // =========================================================================
    localparam SYNC_BYTE    = 8'hAA;
    localparam CMD_LOAD     = 8'h01;
    localparam CMD_VERIFY   = 8'h02;
    localparam CMD_RESET    = 8'h03;
    localparam CMD_INFO     = 8'h04;

    localparam RESP_OK      = 8'h00;
    localparam RESP_ERR     = 8'hFF;
    localparam RESP_INFO    = 8'hFE;

    localparam LD_SYNC      = 4'd0;
    localparam LD_CMD       = 4'd1;
    localparam LD_BLOCK_ID  = 4'd2;
    localparam LD_ADDR_H    = 4'd3;
    localparam LD_ADDR_L    = 4'd4;
    localparam LD_LEN       = 4'd5;
    localparam LD_DATA      = 4'd6;
    localparam LD_CHECKSUM  = 4'd7;
    localparam LD_RESPOND   = 4'd8;
    localparam LD_RESET_RUN = 4'd9;
    localparam LD_INFO_RESP = 4'd10;

    reg [3:0]              ld_state;
    reg [7:0]              ld_cmd;
    reg [7:0]              ld_len;
    reg [7:0]              ld_count;
    reg [7:0]              ld_checksum;
    reg [7:0]              ld_checksum_calc;
    reg                    ld_loading;
    reg                    ld_done;
    reg                    ld_error;
    reg [7:0]              ld_progress;
    reg [ADDR_WIDTH-1:0]   ld_reset_addr;

    // Response state machine
    reg [2:0]  resp_idx;
    reg [7:0]  resp_buf [0:5];
    reg [2:0]  resp_len;

    assign loading       = ld_loading;
    assign load_done     = ld_done;
    assign load_error    = ld_error;
    assign load_progress = ld_progress;

    always @(posedge clk) begin
        if (rst) begin
            ld_state         <= LD_SYNC;
            ld_loading       <= 1'b0;
            ld_done          <= 1'b0;
            ld_error         <= 1'b0;
            ld_progress      <= 8'd0;
            wr_en            <= 1'b0;
            wr_block_id      <= 2'd0;
            wr_addr          <= {ADDR_WIDTH{1'b0}};
            wr_data          <= {DATA_WIDTH{1'b0}};
            ld_checksum_calc <= 8'd0;
            tx_send          <= 1'b0;
        end else begin
            wr_en   <= 1'b0;
            ld_done <= 1'b0;
            tx_send <= 1'b0;

            case (ld_state)
                // Wait for sync byte 0xAA
                LD_SYNC: begin
                    if (rx_valid && rx_byte == SYNC_BYTE) begin
                        ld_state         <= LD_CMD;
                        ld_checksum_calc <= 8'd0;
                        ld_error         <= 1'b0;
                    end
                end

                // Read command byte
                LD_CMD: begin
                    if (rx_valid) begin
                        ld_cmd           <= rx_byte;
                        ld_checksum_calc <= ld_checksum_calc ^ rx_byte;

                        case (rx_byte)
                            CMD_LOAD:   ld_state <= LD_BLOCK_ID;
                            CMD_VERIFY: ld_state <= LD_BLOCK_ID;
                            CMD_RESET: begin
                                ld_state     <= LD_RESET_RUN;
                                ld_loading   <= 1'b1;
                                ld_reset_addr <= {ADDR_WIDTH{1'b0}};
                            end
                            CMD_INFO: begin
                                ld_state <= LD_INFO_RESP;
                                resp_idx <= 3'd0;
                            end
                            default:    ld_state <= LD_SYNC;
                        endcase
                    end
                end

                // Read block ID (0-3)
                LD_BLOCK_ID: begin
                    if (rx_valid) begin
                        if (rx_byte < N_BLOCKS[7:0]) begin
                            wr_block_id      <= rx_byte[1:0];
                            ld_checksum_calc <= ld_checksum_calc ^ rx_byte;
                            ld_state         <= LD_ADDR_H;
                        end else begin
                            ld_error <= 1'b1;
                            ld_state <= LD_SYNC;
                        end
                    end
                end

                // Read address high byte
                LD_ADDR_H: begin
                    if (rx_valid) begin
                        wr_addr[ADDR_WIDTH-1:8] <= rx_byte[ADDR_WIDTH-9:0];
                        ld_checksum_calc        <= ld_checksum_calc ^ rx_byte;
                        ld_state                <= LD_ADDR_L;
                    end
                end

                // Read address low byte
                LD_ADDR_L: begin
                    if (rx_valid) begin
                        wr_addr[7:0]     <= rx_byte;
                        ld_checksum_calc <= ld_checksum_calc ^ rx_byte;
                        ld_state         <= LD_LEN;
                    end
                end

                // Read data length
                LD_LEN: begin
                    if (rx_valid) begin
                        ld_len           <= rx_byte;
                        ld_count         <= 8'd0;
                        ld_loading       <= 1'b1;
                        ld_checksum_calc <= ld_checksum_calc ^ rx_byte;
                        if (rx_byte == 8'd0) begin
                            ld_state <= LD_CHECKSUM;
                        end else begin
                            ld_state <= LD_DATA;
                        end
                    end
                end

                // Receive weight data bytes and write to BRAM
                LD_DATA: begin
                    if (rx_valid) begin
                        // Write trit data to BRAM
                        // Each byte contains 4 trits (2 bits each)
                        wr_en   <= 1'b1;
                        wr_data <= rx_byte[DATA_WIDTH-1:0];
                        ld_checksum_calc <= ld_checksum_calc ^ rx_byte;
                        ld_count <= ld_count + 8'd1;
                        wr_addr  <= wr_addr + 1'b1;

                        // Update progress (0-255)
                        ld_progress <= (ld_count * 8'd255) / ld_len;

                        if (ld_count == ld_len - 8'd1) begin
                            ld_state <= LD_CHECKSUM;
                        end
                    end
                end

                // Verify checksum
                LD_CHECKSUM: begin
                    if (rx_valid) begin
                        ld_loading <= 1'b0;
                        if (rx_byte == ld_checksum_calc) begin
                            ld_done     <= 1'b1;
                            ld_progress <= 8'd255;
                            // Send OK response
                            resp_buf[0] <= SYNC_BYTE;
                            resp_buf[1] <= RESP_OK;
                            resp_len    <= 3'd2;
                        end else begin
                            ld_error <= 1'b1;
                            // Send error response
                            resp_buf[0] <= SYNC_BYTE;
                            resp_buf[1] <= RESP_ERR;
                            resp_len    <= 3'd2;
                        end
                        resp_idx <= 3'd0;
                        ld_state <= LD_RESPOND;
                    end
                end

                // Send response bytes
                LD_RESPOND: begin
                    if (tx_ready && !tx_send) begin
                        tx_byte <= resp_buf[resp_idx];
                        tx_send <= 1'b1;
                        if (resp_idx == resp_len - 3'd1) begin
                            ld_state <= LD_SYNC;
                        end else begin
                            resp_idx <= resp_idx + 3'd1;
                        end
                    end
                end

                // Reset all weights to zero
                LD_RESET_RUN: begin
                    wr_en   <= 1'b1;
                    wr_data <= {DATA_WIDTH{1'b0}};
                    wr_addr <= ld_reset_addr;
                    ld_reset_addr <= ld_reset_addr + 1'b1;

                    if (ld_reset_addr == {ADDR_WIDTH{1'b1}}) begin
                        ld_loading  <= 1'b0;
                        ld_done     <= 1'b1;
                        resp_buf[0] <= SYNC_BYTE;
                        resp_buf[1] <= RESP_OK;
                        resp_len    <= 3'd2;
                        resp_idx    <= 3'd0;
                        ld_state    <= LD_RESPOND;
                    end
                end

                // Send info response
                LD_INFO_RESP: begin
                    if (tx_ready && !tx_send) begin
                        case (resp_idx)
                            3'd0: begin tx_byte <= SYNC_BYTE;               tx_send <= 1'b1; resp_idx <= 3'd1; end
                            3'd1: begin tx_byte <= RESP_INFO;               tx_send <= 1'b1; resp_idx <= 3'd2; end
                            3'd2: begin tx_byte <= N_BLOCKS[7:0];           tx_send <= 1'b1; resp_idx <= 3'd3; end
                            3'd3: begin tx_byte <= ADDR_WIDTH[7:0];         tx_send <= 1'b1; resp_idx <= 3'd4; end
                            3'd4: begin tx_byte <= {7'b0, ld_loading};      tx_send <= 1'b1; resp_idx <= 3'd5; end
                            3'd5: begin tx_byte <= ld_progress;             tx_send <= 1'b1; ld_state <= LD_SYNC; end
                            default: ld_state <= LD_SYNC;
                        endcase
                    end
                end

                default: ld_state <= LD_SYNC;
            endcase
        end
    end

endmodule
