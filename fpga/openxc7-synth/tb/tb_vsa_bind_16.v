// Testbench for VSA Bind 16 operation
`timescale 1ns/1ps

module tb_vsa_bind_16;

    reg clk;
    reg rst;
    reg valid_in;
    reg [31:0] a;
    reg [31:0] b;
    wire valid_out;
    wire [31:0] result;

    vsa_bind_16 dut (
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

    initial begin
        $display("╔════════════════════════════════════════════════════════╗");
        $display("║       VSA Bind 16 Testbench                            ║");
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
        $display("\n[Test 2] +1 * +1 = +1");
        for (i = 0; i < 16; i = i + 1) begin
            a[2*i +: 2] = 2'b01;
            b[2*i +: 2] = 2'b01;
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        for (i = 0; i < 16; i = i + 1) begin
            if (result[2*i +: 2] != 2'b01) begin
                $display("  FAIL: trit %0d", i);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("  PASS");

        // Test 3: All -1 * -1 = +1
        $display("\n[Test 3] -1 * -1 = +1");
        for (i = 0; i < 16; i = i + 1) begin
            a[2*i +: 2] = 2'b10;
            b[2*i +: 2] = 2'b10;
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        for (i = 0; i < 16; i = i + 1) begin
            if (result[2*i +: 2] != 2'b01) begin
                $display("  FAIL: trit %0d", i);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("  PASS");

        // Test 4: +1 * -1 = -1
        $display("\n[Test 4] +1 * -1 = -1");
        for (i = 0; i < 16; i = i + 1) begin
            a[2*i +: 2] = 2'b01;
            b[2*i +: 2] = 2'b10;
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        for (i = 0; i < 16; i = i + 1) begin
            if (result[2*i +: 2] != 2'b10) begin
                $display("  FAIL: trit %0d", i);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("  PASS");

        // Test 5: 0 * X = 0
        $display("\n[Test 5] 0 * X = 0");
        a = 0;
        for (i = 0; i < 16; i = i + 1) begin
            b[2*i +: 2] = (i % 2) ? 2'b01 : 2'b10;
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        if (result == 0)
            $display("  PASS");
        else begin
            $display("  FAIL: expected 0");
            errors = errors + 1;
        end

        // Test 6: Mixed
        $display("\n[Test 6] Mixed values");
        for (i = 0; i < 16; i = i + 1) begin
            case (i % 3)
                0: a[2*i +: 2] = 2'b10;
                1: a[2*i +: 2] = 2'b00;
                2: a[2*i +: 2] = 2'b01;
            endcase
            case ((i * 2) % 3)
                0: b[2*i +: 2] = 2'b10;
                1: b[2*i +: 2] = 2'b00;
                2: b[2*i +: 2] = 2'b01;
            endcase
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        for (i = 0; i < 16; i = i + 1) begin
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
                $display("  FAIL: trit %0d: a=%b b=%b expected=%b got=%b",
                         i, a_trit, b_trit, expected, actual);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("  PASS");

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
        #1000000;
        $display("\n[ERROR] Timeout!");
        $finish;
    end

    initial begin
        $dumpfile("tb_vsa_bind_16.vcd");
        $dumpvars(0, tb_vsa_bind_16);
    end

endmodule
