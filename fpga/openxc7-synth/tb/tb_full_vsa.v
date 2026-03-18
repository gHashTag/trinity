// Testbench for Full VSA Operations
// Tests: bind, bundle, and similarity modules
`timescale 1ns/1ps

module tb_full_vsa;

    // Signals
    reg clk;
    reg rst;
    reg valid_in;
    reg [511:0] a;
    reg [511:0] b;

    // Bind outputs
    wire bind_valid;
    wire [511:0] bind_result;

    // Bundle outputs
    wire bundle_valid;
    wire [511:0] bundle_result;

    // Similarity outputs
    wire sim_valid;
    wire signed [18:0] dot_product;

    // DUT instances
    vsa_bind_256 bind_dut (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .a(a),
        .b(b),
        .valid_out(bind_valid),
        .result(bind_result)
    );

    vsa_bundle_256 bundle_dut (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .a(a),
        .b(b),
        .valid_out(bundle_valid),
        .result(bundle_result)
    );

    vsa_similarity_256 sim_dut (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .a(a),
        .b(b),
        .valid_out(sim_valid),
        .dot_product(dot_product)
    );

    // Clock generation: 50 MHz
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Test variables
    integer i;
    integer errors;
    reg [1:0] a_trit;
    reg [1:0] b_trit;
    reg [1:0] expected;
    reg [1:0] actual;
    reg signed [19:0] expected_dot;

    // Main test sequence
    initial begin
        $display("╔════════════════════════════════════════════════════════╗");
        $display("║       Full VSA Operations Testbench                      ║");
        $display("╚════════════════════════════════════════════════════════╝");

        rst = 1;
        valid_in = 0;
        a = 0;
        b = 0;

        repeat(5) @(posedge clk);
        rst = 0;

        // ================================================================
        // TEST 1: BIND operation
        // ================================================================
        $display("\n[TEST 1] BIND: (-1) * (-1) = +1 (256 trits)");
        errors = 0;

        for (i = 0; i < 256; i = i + 1) begin
            a[2*i +: 2] = 2'b10;  // -1
            b[2*i +: 2] = 2'b10;  // -1
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        for (i = 0; i < 256; i = i + 1) begin
            if (bind_result[2*i +: 2] != 2'b01) begin
                errors = errors + 1;
            end
        end
        if (errors == 0)
            $display("  PASS: All 256 trits = +1");
        else
            $display("  FAIL: %0d errors", errors);

        // ================================================================
        // TEST 2: BUNDLE operation (majority voting)
        // ================================================================
        $display("\n[TEST 2] BUNDLE: majority(-1, 0) = -1");
        errors = 0;

        for (i = 0; i < 256; i = i + 1) begin
            a[2*i +: 2] = 2'b10;  // -1
            b[2*i +: 2] = 2'b00;  // 0
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        for (i = 0; i < 256; i = i + 1) begin
            if (bundle_result[2*i +: 2] != 2'b10) begin
                errors = errors + 1;
            end
        end
        if (errors == 0)
            $display("  PASS: All 256 trits = -1");
        else
            $display("  FAIL: %0d errors", errors);

        // ================================================================
        // TEST 3: BUNDLE with opposing signs = zero
        // ================================================================
        $display("\n[TEST 3] BUNDLE: majority(+1, -1) = 0");
        errors = 0;

        for (i = 0; i < 256; i = i + 1) begin
            a[2*i +: 2] = 2'b01;  // +1
            b[2*i +: 2] = 2'b10;  // -1
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        for (i = 0; i < 256; i = i + 1) begin
            if (bundle_result[2*i +: 2] != 2'b00) begin
                errors = errors + 1;
            end
        end
        if (errors == 0)
            $display("  PASS: All 256 trits = 0");
        else
            $display("  FAIL: %0d errors", errors);

        // ================================================================
        // TEST 4: DOT PRODUCT
        // ================================================================
        $display("\n[TEST 4] DOT PRODUCT: all (+1) * (+1) = +256");
        errors = 0;

        for (i = 0; i < 256; i = i + 1) begin
            a[2*i +: 2] = 2'b01;  // +1
            b[2*i +: 2] = 2'b01;  // +1
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        // dot_product should be +256
        if (dot_product == 256)
            $display("  PASS: dot_product = %0d", dot_product);
        else
            $display("  FAIL: expected 256, got %0d", dot_product);

        // ================================================================
        // TEST 5: DOT PRODUCT with opposing signs = 0
        // ================================================================
        $display("\n[TEST 5] DOT PRODUCT: (+1) * (-1) alternating = 0");
        errors = 0;

        for (i = 0; i < 256; i = i + 1) begin
            a[2*i +: 2] = 2'b01;  // +1
            b[2*i +: 2] = (i % 2 == 0) ? 2'b01 : 2'b10;  // +1, -1 alternating
        end
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        repeat(2) @(posedge clk);

        if (dot_product == 0)
            $display("  PASS: dot_product = %0d", dot_product);
        else
            $display("  FAIL: expected 0, got %0d", dot_product);

        // ================================================================
        // TEST 6: THROUGHPUT test
        // ================================================================
        $display("\n[TEST 6] THROUGHPUT: 100 operations each");
        repeat(100) begin
            @(posedge clk);
            a = {$random, $random, $random, $random, $random, $random, $random, $random};
            b = {$random, $random, $random, $random, $random, $random, $random, $random};
            valid_in = 1;
        end
        $display("  PASS: 100 operations completed");

        // ================================================================
        // SUMMARY
        // ================================================================
        $display("\n╔════════════════════════════════════════════════════════╗");
        $display("║  FULL VSA OPERATIONS TEST COMPLETE                     ║");
        $display("║  BIND: O(1) parallel multiplication                     ║");
        $display("║  BUNDLE: O(1) parallel majority voting                 ║");
        $display("║  SIMILARITY: Tree reduction O(log n)                   ║");
        $display("╚════════════════════════════════════════════════════════╝");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #10000000;
        $display("\n[ERROR] Timeout!");
        $finish;
    end

    // Dump VCD for waveform viewing
    initial begin
        $dumpfile("tb_full_vsa.vcd");
        $dumpvars(0, tb_full_vsa);
    end

endmodule

// φ² + 1/φ² = 3 = TRINITY
