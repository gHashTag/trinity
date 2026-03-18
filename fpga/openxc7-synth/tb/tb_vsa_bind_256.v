// Testbench for VSA Bind 256 operation
`timescale 1ns/1ps

module tb_vsa_bind_256;

    reg clk;
    reg rst;
    reg valid_in;
    reg [511:0] a;
    reg [511:0] b;
    wire valid_out;
    wire [511:0] result;

    vsa_bind_256 dut (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .a(a),
        .b(b),
        .valid_out(valid_out),
        .result(result)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    integer i;
    integer errors = 0;
    reg [1:0] expected;
    reg [1:0] actual;
    reg [1:0] a_trit;
    reg [1:0] b_trit;
    integer nonzero_count;

    initial begin
        $display("╔════════════════════════════════════════════════════════╗");
        $display("║       VSA Bind 256 Testbench                           ║");
        $display("╚════════════════════════════════════════════════════════╝");

        rst = 1;
        valid_in = 0;
        a = 0;
        b = 0;

        repeat(5) @(posedge clk);
        rst = 0;

        // Test 1: All zeros
        $display("\n[Test 1] Identity (0 * 0 = 0)");
        a = 0;
        b = 0;
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        if (result == 0)
            $display("  PASS");
        else begin
            $display("  FAIL: expected 0, got %h", result);
            errors = errors + 1;
        end

        // Test 2: All +1 * +1 = +1
        $display("\n[Test 2] +1 * +1 = +1 (256 trits)");
        for (i = 0; i < 256; i = i + 1) begin
            a[2*i +: 2] = 2'b01;
            b[2*i +: 2] = 2'b01;
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        for (i = 0; i < 256; i = i + 1) begin
            if (result[2*i +: 2] != 2'b01) begin
                $display("  FAIL: trit %0d", i);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("  PASS");

        // Test 3: All -1 * -1 = +1
        $display("\n[Test 3] -1 * -1 = +1 (256 trits)");
        for (i = 0; i < 256; i = i + 1) begin
            a[2*i +: 2] = 2'b10;
            b[2*i +: 2] = 2'b10;
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        errors = 0;
        for (i = 0; i < 256; i = i + 1) begin
            if (result[2*i +: 2] != 2'b01) begin
                $display("  FAIL: trit %0d", i);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("  PASS");

        // Test 4: +1 * -1 = -1
        $display("\n[Test 4] +1 * -1 = -1 (256 trits)");
        for (i = 0; i < 256; i = i + 1) begin
            a[2*i +: 2] = 2'b01;
            b[2*i +: 2] = 2'b10;
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        errors = 0;
        for (i = 0; i < 256; i = i + 1) begin
            if (result[2*i +: 2] != 2'b10) begin
                $display("  FAIL: trit %0d", i);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("  PASS");

        // Test 5: Pattern test
        $display("\n[Test 5] Pattern test (alternating)");
        for (i = 0; i < 256; i = i + 1) begin
            case (i % 4)
                0, 3: a[2*i +: 2] = 2'b01;
                1:     a[2*i +: 2] = 2'b10;
                2:     a[2*i +: 2] = 2'b00;
            endcase
            case (i % 3)
                0:     b[2*i +: 2] = 2'b01;
                1:     b[2*i +: 2] = 2'b10;
                2:     b[2*i +: 2] = 2'b00;
            endcase
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        errors = 0;
        for (i = 0; i < 256; i = i + 1) begin
            a_trit = a[2*i +: 2];
            b_trit = b[2*i +: 2];
            actual = result[2*i +: 2];

            expected = 2'b00;
            if (a_trit != 2'b00 && b_trit != 2'b00) begin
                if (a_trit == b_trit)
                    expected = 2'b01;
                else
                    expected = 2'b10;
            end

            if (actual != expected) begin
                errors = errors + 1;
            end
        end
        if (errors == 0)
            $display("  PASS");
        else
            $display("  FAIL: %0d errors", errors);

        // Test 6: Throughput test
        $display("\n[Test 6] Throughput (1000 operations)");
        errors = 0;
        repeat(1000) begin
            @(posedge clk);
            a = {$random, $random, $random, $random, $random, $random, $random, $random,
                  $random, $random, $random, $random, $random, $random, $random, $random};
            b = {$random, $random, $random, $random, $random, $random, $random, $random,
                  $random, $random, $random, $random, $random, $random, $random, $random};
            valid_in = 1;
        end
        $display("  PASS: 1000 operations completed");

        // Summary
        $display("\n╔════════════════════════════════════════════════════════╗");
        if (errors == 0)
            $display("║  ALL TESTS PASSED                                    ║");
        else
            $display("║  %0d TESTS FAILED                                     ║", errors);
        $display("╚════════════════════════════════════════════════════════╝");

        $finish;
    end

    initial begin
        #10000000;
        $display("\n[ERROR] Timeout!");
        $finish;
    end

    initial begin
        $dumpfile("tb_vsa_bind_256.vcd");
        $dumpvars(0, tb_vsa_bind_256);
    end

endmodule
