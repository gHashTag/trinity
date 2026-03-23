//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// UART WEIGHT LOADER — Testbench
// =============================================================================
`timescale 1ns / 1ps

module uart_weight_loader_tb;

    reg  clk = 0;
    reg  rst = 1;
    reg  uart_rx = 1;
    wire uart_tx;
    wire wr_en;
    wire [1:0]  wr_block_id;
    wire [17:0] wr_addr;
    wire [1:0]  wr_data;
    wire loading;
    wire load_done;
    wire [7:0] load_progress;
    wire load_error;

    uart_weight_loader #(
        .N_BLOCKS(4),
        .ADDR_WIDTH(18),
        .DATA_WIDTH(2),
        .CLK_DIV(27)
    ) uut (
        .clk(clk),
        .rst(rst),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .wr_en(wr_en),
        .wr_block_id(wr_block_id),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .loading(loading),
        .load_done(load_done),
        .load_progress(load_progress),
        .load_error(load_error)
    );

    always #10 clk = ~clk; // 50 MHz

    // UART bit period for 115200 baud at 50 MHz
    localparam BAUD_PERIOD = 50_000_000 / 115200;

    task send_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            uart_rx = 0;
            repeat (BAUD_PERIOD) @(posedge clk);

            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                repeat (BAUD_PERIOD) @(posedge clk);
            end

            // Stop bit
            uart_rx = 1;
            repeat (BAUD_PERIOD) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("uart_weight_loader_tb.vcd");
        $dumpvars(0, uart_weight_loader_tb);

        // Reset
        rst = 1;
        repeat (100) @(posedge clk);
        rst = 0;
        repeat (100) @(posedge clk);

        // === Test 1: GET_INFO command ===
        $display("Test 1: GET_INFO");
        send_byte(8'hAA); // Sync
        send_byte(8'h04); // CMD_INFO
        repeat (10000) @(posedge clk);

        // === Test 2: LOAD_WEIGHTS (block 0, addr 0x0000, 4 bytes) ===
        $display("Test 2: LOAD_WEIGHTS");
        send_byte(8'hAA); // Sync
        send_byte(8'h01); // CMD_LOAD
        send_byte(8'h00); // Block 0
        send_byte(8'h00); // Addr high
        send_byte(8'h00); // Addr low
        send_byte(8'h04); // Length = 4 bytes

        // Weight data: 4 trits per byte
        send_byte(8'b01_10_00_01); // +1, -1, 0, +1
        send_byte(8'b10_01_01_00); // -1, +1, +1, 0
        send_byte(8'b00_00_01_10); // 0, 0, +1, -1
        send_byte(8'b01_01_10_10); // +1, +1, -1, -1

        // Checksum (XOR of cmd, block, addr_h, addr_l, len, data)
        send_byte(8'h01 ^ 8'h00 ^ 8'h00 ^ 8'h00 ^ 8'h04
                  ^ 8'b01_10_00_01 ^ 8'b10_01_01_00
                  ^ 8'b00_00_01_10 ^ 8'b01_01_10_10);

        repeat (10000) @(posedge clk);

        // Check results
        if (load_done)
            $display("PASS: Weight load completed");
        else if (load_error)
            $display("FAIL: Weight load error");
        else
            $display("WARN: Weight load still pending");

        // === Test 3: Invalid block ID ===
        $display("Test 3: Invalid block ID");
        send_byte(8'hAA); // Sync
        send_byte(8'h01); // CMD_LOAD
        send_byte(8'hFF); // Invalid block
        repeat (5000) @(posedge clk);

        if (load_error)
            $display("PASS: Invalid block rejected");
        else
            $display("FAIL: Invalid block not rejected");

        $display("=== All tests complete ===");
        $finish;
    end

endmodule
