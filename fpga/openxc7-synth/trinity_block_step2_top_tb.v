`timescale 1ns / 1ps

module trinity_block_step2_top_tb;

    reg clk;
    wire uart_tx, led;
    wire [1:0] debug_state;

    trinity_block_step2_top uut (
        .clk(clk), .uart_rx(1'b1), .uart_tx(uart_tx),
        .led(led), .debug_state(debug_state)
    );

    always #10 clk = ~clk;

    initial begin
        $dumpfile("tb_step2.vcd");
        $dumpvars(0, trinity_block_step2_top_tb);
        clk = 0;
        $display("=== TRINITY BLOCK STEP 2: MatVec1 + ReLU + MatVec2 ===");
    end

    // Track layer1 completion
    always @(posedge clk) begin
        if (uut.relu_done)
            $display("  Layer1 done — ReLU buffer filled (729 values)");
    end

    // Track layer2 results
    integer result_count;
    initial result_count = 0;

    always @(posedge clk) begin
        if (uut.mv2_valid) begin
            if (result_count < 9)
                $display("  mv2: k=%0d data=%0d expected=%0d match=%b",
                    uut.mv2_addr, $signed(uut.mv2_data),
                    $signed(uut.expected_val),
                    ($signed(uut.mv2_data) == $signed(uut.expected_val)));
            if (result_count == 9)
                $display("  ... (skipping) ...");
            result_count = result_count + 1;
        end

        if (uut.mv2_done) begin
            $display("\nmv2_done! check_count=%0d verify_fail=%b",
                uut.check_count, uut.verify_fail);
        end

        if (uut.st_state == 3'd5 && uut.computation_done) begin
            $display("\n=== RESULT ===");
            $display("  self_test_pass = %b", uut.self_test_pass);
            $display("  verify_fail = %b", uut.verify_fail);
            $display("  check_count = %0d (expected 243)", uut.check_count);
            $display("  Final results[0..7]:");
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

    initial begin
        #1_000_000_000;
        $display("TIMEOUT at state=%0d", uut.st_state);
        $finish;
    end

endmodule
