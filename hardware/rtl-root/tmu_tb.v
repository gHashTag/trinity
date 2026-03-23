// =============================================================================
// TMU Testbench — K=16 Parallel Ternary MatMul Unit verification
// =============================================================================
// Small parameters: N_IN=16, N_OUT=4, K=16
// With K=16 and N_IN=16: steps_per_out=1, each bank handles exactly 1 input.
// Bank b = weights for input i=b.
//
// Tests: known reference, back-to-back start
// =============================================================================

`timescale 1ns / 1ps

module tmu_tb;

    parameter N_IN       = 16;
    parameter N_OUT      = 4;
    parameter K          = 16;
    parameter ACC_WIDTH  = 20;
    parameter I_WIDTH    = 5;
    parameter J_WIDTH    = 3;
    parameter ADDR_WIDTH = 8;

    reg                        clk, rst, start;
    wire signed [ACC_WIDTH-1:0] result_data;
    wire [J_WIDTH-1:0]          result_addr;
    wire                        result_valid;
    wire                        done, busy;

    // Self-test mode (USE_EXT_X=0): x[i] = i + 1
    wire signed [ACC_WIDTH-1:0] x_ext_data;
    wire [I_WIDTH-1:0]          x_ext_addr;
    assign x_ext_data = {ACC_WIDTH{1'b0}};

    tmu #(
        .N_IN           (N_IN),
        .N_OUT          (N_OUT),
        .K              (K),
        .ACC_WIDTH      (ACC_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .I_WIDTH        (I_WIDTH),
        .J_WIDTH        (J_WIDTH),
        .MEM_FILE_PREFIX("tmu_test_w"),
        .USE_EXT_X      (0)
    ) uut (
        .clk         (clk),
        .rst         (rst),
        .start       (start),
        .result_data (result_data),
        .result_addr (result_addr),
        .result_valid(result_valid),
        .done        (done),
        .busy        (busy),
        .x_ext_data  (x_ext_data),
        .x_ext_addr  (x_ext_addr)
    );

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Capture results
    reg signed [ACC_WIDTH-1:0] results [0:N_OUT-1];

    always @(posedge clk) begin
        if (result_valid) begin
            results[result_addr] <= result_data;
        end
    end

    // =========================================================================
    // Test execution
    // =========================================================================
    integer pass_count;
    integer fail_count;

    task reset_dut;
        begin
            rst = 1;
            start = 0;
            #20;
            rst = 0;
            #10;
        end
    endtask

    task run_matvec;
        begin
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;
            while (!done) @(posedge clk);
            @(posedge clk);
        end
    endtask

    task check_result;
        input [J_WIDTH-1:0] idx;
        input signed [ACC_WIDTH-1:0] expected;
        input [8*32-1:0] test_name;
        begin
            if (results[idx] === expected) begin
                $display("  PASS: %0s — y[%0d] = %0d (expected %0d)", test_name, idx, results[idx], expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: %0s — y[%0d] = %0d (expected %0d)", test_name, idx, results[idx], expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tmu_tb.vcd");
        $dumpvars(0, tmu_tb);

        pass_count = 0;
        fail_count = 0;

        // =================================================================
        // Test 1: Known weights → hand-computed reference
        // =================================================================
        // K=16, N_IN=16: steps_per_out = ceil(16/16) = 1
        // Bank b handles input i=b. Each bank has N_OUT=4 entries (one per output j).
        //
        // Weight matrix:
        //   j=0: all +1        → y[0] = sum(1..16) = 136
        //   j=1: alt +1/-1     → y[1] = 1-2+3-4+...+15-16 = -8
        //   j=2: first 8 = +1  → y[2] = sum(1..8) = 36
        //   j=3: all -1        → y[3] = -sum(1..16) = -136

        $display("\n=== TEST 1: Known weights (hand-computed) ===");
        reset_dut;
        run_matvec;

        check_result(0,  136, "all +1");
        check_result(1,   -8, "alternating +1/-1");
        check_result(2,   36, "first 8 = +1, rest 0");
        check_result(3, -136, "all -1");

        // =================================================================
        // Test 2: Back-to-back start — no state corruption
        // =================================================================
        $display("\n=== TEST 2: Back-to-back start ===");
        run_matvec;

        check_result(0,  136, "b2b all +1");
        check_result(1,   -8, "b2b alternating");
        check_result(2,   36, "b2b first 8");
        check_result(3, -136, "b2b all -1");

        // =================================================================
        // Summary
        // =================================================================
        $display("\n============================================");
        if (fail_count == 0)
            $display("ALL TESTS PASSED (%0d/%0d)", pass_count, pass_count);
        else
            $display("FAILED: %0d/%0d tests failed", fail_count, pass_count + fail_count);
        $display("============================================\n");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #200000;
        $display("TIMEOUT: simulation exceeded 200us");
        $finish;
    end

endmodule
