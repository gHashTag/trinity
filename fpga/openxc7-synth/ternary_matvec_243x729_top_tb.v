`timescale 1ns / 1ps

// Full simulation testbench for 243x729 streaming self-test
module ternary_matvec_243x729_top_tb;

    reg clk;
    wire uart_tx, led;
    wire [1:0] debug_state;

    ternary_matvec_243x729_top uut (
        .clk(clk),
        .uart_rx(1'b1),
        .uart_tx(uart_tx),
        .led(led),
        .debug_state(debug_state)
    );

    always #10 clk = ~clk;  // 50 MHz

    initial begin
        $dumpfile("tb_243x729.vcd");
        $dumpvars(0, ternary_matvec_243x729_top_tb);
        clk = 0;

        // Monitor key signals
        $display("=== 243x729 STREAMING SELF-TEST SIMULATION ===");
        $display("Waiting for POR (255 clocks)...");
    end

    // Track first few results
    integer result_count;
    initial result_count = 0;

    always @(posedge clk) begin
        if (uut.mv_valid) begin
            if (result_count < 12) begin
                $display("  mv_valid: addr=%0d data=%0d (signed=%0d) expected=%0d match=%b",
                    uut.mv_addr,
                    uut.mv_data,
                    $signed(uut.mv_data),
                    $signed(uut.expected_val),
                    ($signed(uut.mv_data) == $signed(uut.expected_val)));
            end
            if (result_count == 12)
                $display("  ... (skipping middle results) ...");
            result_count = result_count + 1;
        end

        // Report when verify_fail goes high
        if (uut.verify_fail && result_count > 0 && result_count < 730) begin
            $display("  *** VERIFY_FAIL at check_count=%0d j_mod3=%0d ***",
                uut.check_count, uut.j_mod3);
        end

        if (uut.mv_done) begin
            $display("\nmv_done! check_count=%0d verify_fail=%b",
                uut.check_count, uut.verify_fail);
            $display("  N_OUT=%0d, match=%b",
                729, (uut.check_count == 729));
        end

        if (uut.st_state == 2'd3 && uut.computation_done) begin  // ST_DONE
            $display("\n=== RESULT ===");
            $display("  self_test_pass = %b", uut.self_test_pass);
            $display("  computation_done = %b", uut.computation_done);
            $display("  verify_fail = %b", uut.verify_fail);
            $display("  check_count = %0d (expected 729)", uut.check_count);
            $display("  led = %b (0=ON, 1=OFF)", led);
            $display("  debug_state = %b", debug_state);
            if (uut.self_test_pass)
                $display("  >>> PASS — D6 should be ON <<<");
            else
                $display("  >>> FAIL — D6 will be OFF <<<");
            #100 $finish;
        end
    end

    // Timeout
    initial begin
        #500_000_000;  // 500ms = enough for 243x729 (~180K clocks = 3.6ms)
        $display("TIMEOUT — self-test never completed");
        $display("  st_state=%0d busy=%b mv_start=%b",
            uut.st_state, uut.core.busy, uut.mv_start);
        $finish;
    end

endmodule
