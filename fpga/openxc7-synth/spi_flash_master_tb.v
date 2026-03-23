//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// SPI FLASH MASTER — Testbench with W25Q128 model
// =============================================================================
`timescale 1ns / 1ps

module spi_flash_master_tb;

    reg  clk = 0;
    reg  rst = 1;
    wire spi_cs_n;
    wire spi_sclk;
    wire spi_mosi;
    reg  spi_miso = 0;

    reg        start = 0;
    reg [23:0] flash_addr = 24'd0;
    reg [15:0] read_len = 16'd0;
    wire       busy;
    wire       done;
    wire       bram_wr_en;
    wire [17:0] bram_wr_addr;
    wire [7:0]  bram_wr_data;

    spi_flash_master #(
        .CLK_DIV(2),
        .ADDR_WIDTH(24),
        .BRAM_AWIDTH(18),
        .DATA_WIDTH(8)
    ) uut (
        .clk(clk),
        .rst(rst),
        .spi_cs_n(spi_cs_n),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .start(start),
        .flash_addr(flash_addr),
        .read_len(read_len),
        .busy(busy),
        .done(done),
        .bram_wr_en(bram_wr_en),
        .bram_wr_addr(bram_wr_addr),
        .bram_wr_data(bram_wr_data)
    );

    always #10 clk = ~clk; // 50 MHz

    // Simple W25Q128 Flash model
    reg [7:0] flash_mem [0:255];
    reg [7:0] spi_rx_shift;
    reg [2:0] spi_rx_cnt;
    reg [7:0] spi_tx_shift;
    reg [2:0] spi_tx_cnt;
    reg [4:0] spi_state;
    reg [23:0] spi_addr;

    localparam S_CMD  = 0;
    localparam S_ADDR = 1;
    localparam S_DATA = 2;

    initial begin
        integer i;
        for (i = 0; i < 256; i = i + 1)
            flash_mem[i] = i[7:0]; // Test pattern: addr = data
    end

    // SPI slave model (simplified)
    always @(posedge spi_sclk or posedge spi_cs_n) begin
        if (spi_cs_n) begin
            spi_state   <= S_CMD;
            spi_rx_cnt  <= 3'd7;
            spi_tx_cnt  <= 3'd7;
        end else begin
            // Shift in MOSI
            spi_rx_shift <= {spi_rx_shift[6:0], spi_mosi};
            if (spi_rx_cnt == 3'd0) begin
                spi_rx_cnt <= 3'd7;
                case (spi_state)
                    S_CMD: begin
                        spi_state <= S_ADDR;
                        spi_rx_cnt <= 3'd7;
                    end
                    S_ADDR: begin
                        spi_addr <= {spi_addr[15:0], spi_rx_shift[6:0], spi_mosi};
                        if (spi_addr[23:16] != 8'd0 || spi_addr[15:8] != 8'd0) begin
                            // All 3 addr bytes received
                            spi_state <= S_DATA;
                            spi_tx_shift <= flash_mem[{spi_rx_shift[6:0], spi_mosi}];
                        end
                    end
                    S_DATA: begin
                        spi_addr <= spi_addr + 1'b1;
                        spi_tx_shift <= flash_mem[spi_addr[7:0] + 1'b1];
                    end
                endcase
            end else
                spi_rx_cnt <= spi_rx_cnt - 1'b1;
        end
    end

    // MISO output on falling edge
    always @(negedge spi_sclk or posedge spi_cs_n) begin
        if (spi_cs_n)
            spi_miso <= 1'b0;
        else if (spi_state == S_DATA) begin
            spi_miso <= spi_tx_shift[7];
            spi_tx_shift <= {spi_tx_shift[6:0], 1'b0};
        end
    end

    // Capture written data
    reg [7:0] captured_data [0:255];
    integer wr_count = 0;

    always @(posedge clk) begin
        if (bram_wr_en) begin
            captured_data[wr_count] <= bram_wr_data;
            wr_count <= wr_count + 1;
        end
    end

    initial begin
        $dumpfile("spi_flash_master_tb.vcd");
        $dumpvars(0, spi_flash_master_tb);

        // Reset
        rst = 1;
        repeat (100) @(posedge clk);
        rst = 0;
        repeat (100) @(posedge clk);

        // Read 8 bytes from address 0
        $display("Test: Read 8 bytes from Flash addr 0x000000");
        flash_addr = 24'h000000;
        read_len   = 16'd8;
        start      = 1;
        @(posedge clk);
        start = 0;

        // Wait for completion
        wait (done);
        repeat (10) @(posedge clk);

        $display("Read complete, %0d bytes written to BRAM", wr_count);
        $display("=== SPI Flash Master test complete ===");

        $finish;
    end

endmodule
