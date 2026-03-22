// @origin(spec:tf3_alu_tb.tri) @regen(manual-impl)
// TF3 ALU Testbench
//
// Verifies TF3-9 arithmetic against Zig reference implementation
// Test cases generated to match TernaryFloat9 behavior
//
// φ² + 1/φ² = 3 | TRINITY

`timescale 1ns / 1ps

module tf3_alu_tb;

    // ========================================================================
    // DUT instantiation
    // ========================================================================

    reg         clk;
    reg         rst;
    reg [1:0]  mode;
    reg         in_valid;
    reg [17:0] in_a;
    reg [17:0] in_b;
    reg [7:0]  dot_len;

    wire        in_ready;
    wire        out_valid;
    wire [17:0] out_y;
    reg         out_ready;

    // Instantiate TF3 ALU
    tf3_alu uut (
        .clk(clk),
        .rst(rst),
        .mode(mode),
        .in_valid(in_valid),
        .in_a(in_a),
        .in_b(in_b),
        .dot_len(dot_len),
        .in_ready(in_ready),
        .out_valid(out_valid),
        .out_y(out_y),
        .out_ready(out_ready)
    );

    // ========================================================================
    // Test state tracking
    // ========================================================================

    integer test_num;
    integer error_count;
    integer tests_passed;

    // ========================================================================
    // Clock generation (100 MHz)
    // ========================================================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz period = 10ns
    end

    // ========================================================================
    // Task: Run test cases
    // ========================================================================

    task run_test;
        input [1:0] test_mode;
        input [17:0] test_a;
        input [17:0] test_b;
        input [7:0]  expected_len; // For dot product
        begin
            @(posedge clk);
            rst = 1;
            @(posedge clk);
            rst = 0;

            mode = test_mode;
            in_a = test_a;
            in_b = test_b;
            dot_len = expected_len;
            in_valid = 1;
            out_ready = 0;
            #1; // Initial delay to stabilize

            // Wait for in_ready
            @(posedge clk);
            while (!in_ready) begin
                @(posedge clk);
            end

            @(posedge clk);
            in_valid = 0;
            #5; // Extra delay to stabilize signals

            // Wait for output
            @(posedge clk);
            out_ready = 1;
            while (!out_valid) begin
                @(posedge clk);
            end

            @(posedge clk);
            out_ready = 0;

            // Extra delay before reading result
            #20;
            @(posedge clk);
            out_ready = 0;
            while (!out_valid) begin
                @(posedge clk);
            end

            @(posedge clk);
            // Read and check result
            if (out_valid) begin
                #5; // Wait for result to propagate
                out_ready = 0;
            end

            // Delay before next test
            #5;
        end
    endtask

    // ========================================================================
    // Helper: Check result
    // ========================================================================

    task check_result;
        input [17:0] expected;
        begin
            if (out_y !== expected) begin
                $display("[%0t] FAIL: Expected 0x%h, Got 0x%h",
                         $time, expected, out_y);
                error_count = error_count + 1;
            end else begin
                tests_passed = tests_passed + 1;
            end
        end
    endtask

    // ========================================================================
    // Main test sequence
    // ========================================================================

    initial begin
        test_num = 0;
        error_count = 0;
        tests_passed = 0;

        $display("\n\n========================================");
        $display("  TF3 ALU Testbench");
        $display("========================================\n");

        $display("Test mode: 00=add, 01=dot");

        // ====================================================================
        // Test 1: TF3 Addition - Zero + Zero
        // ====================================================================
        test_num = 1;
        $display("\nTest %0d: Zero + Zero", test_num);
        run_test(2'b00,
                 18'b0000000000000000000,   // A = 0
                 18'b0000000000000000000,   // B = 0
                 8'd0);
        check_result(18'b0000000000000000000); // Expected: 0

        // ====================================================================
        // Test 2: TF3 Addition - Positive + Zero
        // ====================================================================
        test_num = 2;
        $display("\nTest %0d: +1 + 0", test_num);
        run_test(2'b00,
                 18'b1000000000000000001,   // A = +1 (sign=10)
                 18'b0000000000000000000,   // B = 0
                 8'd0);
        check_result(18'b1000000000000000001); // Expected: +1

        // ====================================================================
        // Test 3: TF3 Addition - Negative + Zero
        // ====================================================================
        test_num = 3;
        $display("\nTest %0d: -1 + 0", test_num);
        run_test(2'b00,
                 18'b0100000000000000001,   // A = -1 (sign=01)
                 18'b0000000000000000000,   // B = 0
                 8'd0);
        check_result(18'b0100000000000000001); // Expected: -1

        // ====================================================================
        // Test 4: TF3 Addition - Positive + Negative (cancel)
        // ====================================================================
        test_num = 4;
        $display("\nTest %0d: +1 + (-1)", test_num);
        run_test(2'b00,
                 18'b1000000000000000001,   // A = +1
                 18'b0100000000000000001,   // B = -1
                 8'd0);
        check_result(18'b0000000000000000000); // Expected: 0

        // ====================================================================
        // Test 5: TF3 Addition - Positive + Positive
        // ====================================================================
        test_num = 5;
        $display("\nTest %0d: +1 + +1", test_num);
        run_test(2'b00,
                 18'b1000000000000000001,   // A = +1
                 18'b1000000000000000001,   // B = +1
                 8'd0);
        // For saturating addition, +1+1 should still be +1
        check_result(18'b1000000000000000010); // Expected: +1+1=+1

        // ====================================================================
        // Test 6: TF3 Dot Product - Single element
        // ====================================================================
        test_num = 6;
        $display("\nTest %0d: Dot Product - N=1", test_num);
        run_test(2'b01,
                 18'b1000000000000000001,   // A = +1
                 18'b1000000000000000001,   // B = +1
                 8'd1);   // N=1
        check_result(18'b1000000000000000001); // Expected: +1

        // ====================================================================
        // Test 7: TF3 Dot Product - N=2
        // ====================================================================
        test_num = 7;
        $display("\nTest %0d: Dot Product - N=2", test_num);
        run_test(2'b01,
                 18'b1000000000000000001,   // A = +1
                 18'b1000000000000000001,   // B = +1
                 8'd2);   // N=2
        // For dot product with N=2: +1*2 = +1+1
        check_result(18'b1000000000000000010); // Expected: +1+1=+2

        // ====================================================================
        // Test 8: TF3 Dot Product - N=2 (mixed signs)
        // ====================================================================
        test_num = 8;
        $display("\nTest %0d: Dot Product - N=2 (mixed signs)", test_num);
        run_test(2'b01,
                 18'b1000000000000000001,   // A = +1
                 18'b0100000000000000001,   // B = -1
                 8'd2);   // N=2
        // For dot product with N=2: (+1)*(-1)*2 = -1-1-1 = -2
        // TF3-9 format: sign=-1 (01), exp=0, mant should show negative magnitude
        // Expected: result sign=01 (negative), exp should be >=0
        check_result(18'b0100000000000000010); // Expected: -2

        // ====================================================================
        // Test 9: All zeros
        // ====================================================================
        test_num = 9;
        $display("\nTest %0d: All zeros", test_num);
        run_test(2'b00,
                 18'b0000000000000000000,   // A = 0
                 18'b0000000000000000000,   // B = 0
                 8'd0);
        check_result(18'b0000000000000000000); // Expected: 0

        // ====================================================================
        // Summary
        // ====================================================================

        #50; // Wait for final operations
        $display("\n\n========================================");
        $display("  Test Summary");
        $display("========================================");
        $display("Tests Passed: %0d", tests_passed);
        $display("Tests Failed: %0d", error_count);
        $display("Total Tests:  %0d", tests_passed + error_count);

        if (error_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***\n");
        end else begin
            $display("\n*** %0d TEST(S) FAILED ***\n", error_count);
        end

        #100;
        $finish;
    end

endmodule
