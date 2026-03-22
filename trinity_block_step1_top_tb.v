`timescale 1ns / 1ps

module trinity_block_step1_top_tb;

    reg clk;
    wire uart_tx, led;
    wire [1:0] debug_state;

    trinity_block_step1_top uut (
        .clk(clk),
        .uart_rx(1'b1),
        .uart_tx(uart_tx),
        .led(led),
        .debug_state(debug_state)
    );

    always #10 clk = ~clk;  // 50 MHz

    initial begin
        $dumpfile("tb_step1.vcd");
        $dumpvars(0, trinity_block_step1_top_tb);
        clk = 0;
        $display("=== TRINITY BLOCK STEP 1: MatVec + ReLU ===");
        $display("Waiting for POR (255 clocks)...");
    end

    // Track post-ReLU results
    integer result_count;
    initial result_count = 0;

    always @(posedge clk) begin
        if (uut.relu_valid) begin
            if (result_count < 12) begin
                $display("  relu_valid: addr=%0d data=%0d expected=%0d match=%b",
                    uut.mv_addr_d1,
                    $signed(uut.relu_data),
                    $signed(uut.expected_val),
                    (uut.relu_data == uut.expected_val));
            end
            if (result_count == 12)
                $display("  ... (skipping middle results) ...");
            result_count = result_count + 1;
        end

        if (uut.verify_fail && result_count > 0 && result_count < 730) begin
            $display("  *** VERIFY_FAIL at check_count=%0d j_mod3=%0d ***",
                uut.check_count, uut.j_mod3);
        end

        if (uut.relu_done) begin
            $display("\nrelu_done! check_count=%0d verify_fail=%b",
                uut.check_count, uut.verify_fail);
        end

        if (uut.st_state == 2'd3 && uut.computation_done) begin
            $display("\n=== RESULT ===");
            $display("  self_test_pass = %b", uut.self_test_pass);
            $display("  computation_done = %b", uut.computation_done);
            $display("  verify_fail = %b", uut.verify_fail);
            $display("  check_count = %0d (expected 729)", uut.check_count);
            $display("  led = %b (0=ON, 1=OFF)", led);
            $display("  Post-ReLU results[0..7]:");
            $display("    [0]=%0d [1]=%0d [2]=%0d [3]=%0d",
                $signed(uut.uart_results[0]), $signed(uut.uart_results[1]),
                $signed(uut.uart_results[2]), $signed(uut.uart_results[3]));
            $display("    [4]=%0d [5]=%0d [6]=%0d [7]=%0d",
                $signed(uut.uart_results[4]), $signed(uut.uart_results[5]),
                $signed(uut.uart_results[6]), $signed(uut.uart_results[7]));
            if (uut.self_test_pass)
                $display("  >>> PASS — D6 should be ON <<<");
            else
                $display("  >>> FAIL — D6 will be OFF <<<");
            #100 $finish;
        end
    end

    // Timeout
    initial begin
        #500_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
