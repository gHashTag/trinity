// =============================================================================
// SPI FLASH MASTER — Read weights from W25Q128 SPI Flash
// =============================================================================
// Reads ternary weights from external SPI Flash into BRAM at boot time.
// W25Q128 on QMTECH board: 128Mbit = 16MB (enough for ~50 TrinityBlocks)
//
// SPI Mode 0: CPOL=0, CPHA=0
// Clock: 50MHz / 8 = 6.25MHz SPI clock
//
// Read sequence:
//   1. Assert CS_N low
//   2. Send READ command (0x03)
//   3. Send 24-bit address
//   4. Clock out data bytes
//   5. Deassert CS_N
//
// Weight storage format in Flash:
//   Offset 0x000000: Header (8 bytes: magic, version, n_blocks, dim)
//   Offset 0x000100: Block 0 up-projection weights (243*729 trits)
//   Offset 0x010000: Block 0 down-projection weights
//   ...
//
// Resource estimate: ~150 LUT, 0 BRAM, 0 DSP48
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module spi_flash_master #(
    parameter CLK_DIV     = 4,        // SPI clock divider (50MHz/4/2 = 6.25MHz)
    parameter ADDR_WIDTH  = 24,       // 24-bit Flash address
    parameter BRAM_AWIDTH = 18,       // BRAM address width
    parameter DATA_WIDTH  = 8         // SPI data width (byte)
)(
    input  wire clk,
    input  wire rst,

    // SPI interface
    output reg  spi_cs_n,
    output reg  spi_sclk,
    output reg  spi_mosi,
    input  wire spi_miso,

    // Control interface
    input  wire                    start,       // Start read transfer
    input  wire [ADDR_WIDTH-1:0]   flash_addr,  // Flash start address
    input  wire [15:0]             read_len,    // Number of bytes to read
    output reg                     busy,
    output reg                     done,

    // BRAM write interface
    output reg                     bram_wr_en,
    output reg  [BRAM_AWIDTH-1:0]  bram_wr_addr,
    output reg  [DATA_WIDTH-1:0]   bram_wr_data
);

    // SPI commands
    localparam SPI_CMD_READ       = 8'h03;  // Read Data
    localparam SPI_CMD_FAST_READ  = 8'h0B;  // Fast Read (with dummy byte)
    localparam SPI_CMD_RDID       = 8'h9F;  // Read JEDEC ID
    localparam SPI_CMD_RDSR       = 8'h05;  // Read Status Register

    // FSM states
    localparam ST_IDLE      = 4'd0;
    localparam ST_CS_LOW    = 4'd1;
    localparam ST_SEND_CMD  = 4'd2;
    localparam ST_SEND_ADDR = 4'd3;
    localparam ST_READ_DATA = 4'd4;
    localparam ST_CS_HIGH   = 4'd5;
    localparam ST_DONE      = 4'd6;

    reg [3:0]  state;
    reg [7:0]  spi_clk_cnt;
    reg [7:0]  shift_reg;
    reg [2:0]  bit_cnt;
    reg [23:0] addr_reg;
    reg [15:0] byte_cnt;
    reg [15:0] total_bytes;
    reg [1:0]  addr_byte_cnt;
    reg        sclk_en;

    // SPI clock generation
    reg [7:0]  clk_div_cnt;
    reg        spi_clk_edge;  // Rising edge of SPI clock
    reg        spi_clk_fall;  // Falling edge of SPI clock

    always @(posedge clk) begin
        if (rst) begin
            clk_div_cnt  <= 8'd0;
            spi_clk_edge <= 1'b0;
            spi_clk_fall <= 1'b0;
        end else begin
            spi_clk_edge <= 1'b0;
            spi_clk_fall <= 1'b0;
            if (clk_div_cnt == CLK_DIV - 1) begin
                clk_div_cnt <= 8'd0;
                if (sclk_en) begin
                    if (!spi_sclk) begin
                        spi_sclk     <= 1'b1;
                        spi_clk_edge <= 1'b1;  // Rising edge: sample MISO
                    end else begin
                        spi_sclk     <= 1'b0;
                        spi_clk_fall <= 1'b1;  // Falling edge: shift MOSI
                    end
                end
            end else
                clk_div_cnt <= clk_div_cnt + 1'b1;
        end
    end

    // Main FSM
    always @(posedge clk) begin
        if (rst) begin
            state        <= ST_IDLE;
            spi_cs_n     <= 1'b1;
            spi_sclk     <= 1'b0;
            spi_mosi     <= 1'b0;
            sclk_en      <= 1'b0;
            busy         <= 1'b0;
            done         <= 1'b0;
            bram_wr_en   <= 1'b0;
            bram_wr_addr <= {BRAM_AWIDTH{1'b0}};
        end else begin
            bram_wr_en <= 1'b0;
            done       <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (start && !busy) begin
                        busy        <= 1'b1;
                        addr_reg    <= flash_addr;
                        total_bytes <= read_len;
                        byte_cnt    <= 16'd0;
                        bram_wr_addr <= {BRAM_AWIDTH{1'b0}};
                        state       <= ST_CS_LOW;
                    end
                end

                // Assert CS
                ST_CS_LOW: begin
                    spi_cs_n <= 1'b0;
                    shift_reg <= SPI_CMD_READ;
                    bit_cnt   <= 3'd7;
                    sclk_en   <= 1'b1;
                    spi_mosi  <= SPI_CMD_READ[7];
                    state     <= ST_SEND_CMD;
                end

                // Send READ command (8 bits)
                ST_SEND_CMD: begin
                    if (spi_clk_fall) begin
                        if (bit_cnt == 3'd0) begin
                            // Command sent, now send address
                            addr_byte_cnt <= 2'd0;
                            shift_reg     <= addr_reg[23:16];
                            bit_cnt       <= 3'd7;
                            spi_mosi      <= addr_reg[23];
                            state         <= ST_SEND_ADDR;
                        end else begin
                            bit_cnt  <= bit_cnt - 1'b1;
                            spi_mosi <= shift_reg[bit_cnt - 1];
                        end
                    end
                end

                // Send 24-bit address (3 bytes)
                ST_SEND_ADDR: begin
                    if (spi_clk_fall) begin
                        if (bit_cnt == 3'd0) begin
                            if (addr_byte_cnt == 2'd2) begin
                                // Address sent, start reading data
                                bit_cnt  <= 3'd7;
                                spi_mosi <= 1'b0;
                                state    <= ST_READ_DATA;
                            end else begin
                                addr_byte_cnt <= addr_byte_cnt + 1'b1;
                                case (addr_byte_cnt)
                                    2'd0: begin shift_reg <= addr_reg[15:8];  spi_mosi <= addr_reg[15]; end
                                    2'd1: begin shift_reg <= addr_reg[7:0];   spi_mosi <= addr_reg[7];  end
                                    default: ;
                                endcase
                                bit_cnt <= 3'd7;
                            end
                        end else begin
                            bit_cnt  <= bit_cnt - 1'b1;
                            spi_mosi <= shift_reg[bit_cnt - 1];
                        end
                    end
                end

                // Read data bytes from Flash
                ST_READ_DATA: begin
                    if (spi_clk_edge) begin
                        // Sample MISO on rising edge
                        shift_reg <= {shift_reg[6:0], spi_miso};
                        if (bit_cnt == 3'd0) begin
                            // Full byte received
                            bram_wr_data <= {shift_reg[6:0], spi_miso};
                            bram_wr_en   <= 1'b1;
                            bram_wr_addr <= bram_wr_addr + 1'b1;
                            byte_cnt     <= byte_cnt + 16'd1;

                            if (byte_cnt == total_bytes - 16'd1) begin
                                state <= ST_CS_HIGH;
                            end else begin
                                bit_cnt <= 3'd7;
                            end
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end
                end

                // Deassert CS
                ST_CS_HIGH: begin
                    spi_cs_n <= 1'b1;
                    sclk_en  <= 1'b0;
                    spi_sclk <= 1'b0;
                    state    <= ST_DONE;
                end

                ST_DONE: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
