`default_nettype none

// ═════════════════════════════════════════════════════════════════════════
// SACRED ALU BENCHMARK TESTBENCH (Phase 6.2)
// ═════════════════════════════════════════════════════════════════════════
//
// Purpose: Measure performance (latency and throughput) for all Sacred ALU modes
//
// Operations:
//   - GF16_ADD, GF16_MUL, TF3_ADD, TF3_DOT
//   - 100K operations per mode (configurable via BENCH_OPS)
//
// Output: cycles_per_op and ops_per_sec for each mode
//
// φ² + 1/φ² = 3 | TRINITY

`timescale 1ns/1ps

// ================================================================================
// BENCHMARK PARAMETERS
// ================================================================================
`define BENCH_OPS        100000  // Operations per mode (default: 100K)
`define CLOCK_PERIOD    10      // 100 MHz clock (10ns period)
`define TIMEOUT_CYCLES 10000000 // 10M cycles timeout for safety

module tb_bench_sacred;

    // ============================================================================
    // CLOCK AND RESET
    // ============================================================================
    reg clk = 0;
    reg rst_n = 0;

    // Generate 100 MHz clock
    always #(`CLOCK_PERIOD / 2) clk = ~clk;

    // ============================================================================
    // DUT SIGNALS
    // ============================================================================
    reg in_valid;
    wire in_ready;
    reg [1:0] mode;
    reg [31:0] in_a;
    reg [31:0] in_b;
    wire out_valid;
    reg out_ready;
    wire [31:0] out_y;

    // Benchmark signals
    reg bench_enable;
    reg [31:0] bench_ops_target;
    wire [31:0] bench_result_cycle_count;
    wire [31:0] bench_result_ops_done;
    wire bench_result_done;

    // ============================================================================
    // DUT INSTANTIATION
    // ============================================================================
    sacred_alu dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .mode(mode),
        .in_a(in_a),
        .in_b(in_b),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_y(out_y),

        // Benchmark interface
        .bench_enable(bench_enable),
        .bench_ops_target(bench_ops_target),
        .bench_result_cycle_count(bench_result_cycle_count),
        .bench_result_ops_done(bench_result_ops_done),
        .bench_result_done(bench_result_done)
    );

    // ============================================================================
    // TEST RESULT STORAGE
    // ============================================================================
    integer cycles_per_op [3:0];    // 4 modes × 4 measurements
    integer ops_per_sec [3:0];    // 4 modes × 4 measurements
    real cycles_per_op_real [3:0];
    real ops_per_sec_real [3:0];

    // Mode names for display
    reg [79:0] mode_name [3:0];
    initial begin
        mode_name[0] = "GF16_ADD";
        mode_name[1] = "GF16_MUL";
        mode_name[2] = "TF3_ADD";
        mode_name[3] = "TF3_DOT";
    end

    // ============================================================================
    // TEST CONTROL
    // ============================================================================
    integer test_mode = 0;  // Current mode being tested
    integer timeout_counter = 0;

    // ============================================================================
    // MAIN TEST SEQUENCE
    // ============================================================================
    initial begin
        // Print header
        $display("\n╔═════════════════════════════════════════════════════════════════════╗");
        $display("║         SACRED ALU BENCHMARK TESTBENCH (Phase 6.2)                  ║");
        $display("║  GF16/TF3-9 Performance on Artix-7 XC7A100T                 ║");
        $display("╚═════════════════════════════════════════════════════════════════════╝");
        $display("  Benchmark operations per mode: %0d", `BENCH_OPS);
        $display("  Clock frequency: %0.0f MHz (period = %0dns)", 1000.0 / `CLOCK_PERIOD, `CLOCK_PERIOD);
        $display("");

        // Reset sequence
        rst_n = 0;
        in_valid = 0;
        out_ready = 1;
        bench_enable = 0;
        bench_ops_target = `BENCH_OPS;
        #(10 * `CLOCK_PERIOD);
        rst_n = 1;
        #(5 * `CLOCK_PERIOD);

        // Run benchmarks for all 4 modes
        $display("=== Starting benchmark sequence ===\n");

        // Mode 0: GF16_ADD
        run_benchmark(2'b00, "GF16_ADD");

        // Mode 1: GF16_MUL
        run_benchmark(2'b01, "GF16_MUL");

        // Mode 2: TF3_ADD
        run_benchmark(2'b10, "TF3_ADD");

        // Mode 3: TF3_DOT
        run_benchmark(2'b11, "TF3_DOT");

        // Print summary
        $display("\n╔═════════════════════════════════════════════════════════════════════╗");
        $display("║               SACRED ALU BENCHMARK RESULTS                        ║");
        $display("╠═════════════════════════════════════════════════════════════════════╣");
        $display("║ Mode        │ Cycles/op │ Throughput │ Clock Freq        ║");
        $display("╠═════════════════════════════════════════════════════════════════════╣");

        $display("║ %0s │ %8.2f     │ %8.2f GOP/s │ %4.0f MHz          ║",
            mode_name[0], cycles_per_op_real[0], ops_per_sec_real[0] / 1e9, 1000.0 / `CLOCK_PERIOD);
        $display("║ %0s │ %8.2f     │ %8.2f GOP/s │ %4.0f MHz          ║",
            mode_name[1], cycles_per_op_real[1], ops_per_sec_real[1] / 1e9, 1000.0 / `CLOCK_PERIOD);
        $display("║ %0s │ %8.2f     │ %8.2f GOP/s │ %4.0f MHz          ║",
            mode_name[2], cycles_per_op_real[2], ops_per_sec_real[2] / 1e9, 1000.0 / `CLOCK_PERIOD);
        $display("║ %0s │ %8.2f     │ %8.2f GOP/s │ %4.0f MHz          ║",
            mode_name[3], cycles_per_op_real[3], ops_per_sec_real[3] / 1e9, 1000.0 / `CLOCK_PERIOD);

        $display("╚═════════════════════════════════════════════════════════════════════╝");

        // CSV output for easy parsing
        $display("\n# CSV OUTPUT (for tri sacred bench parsing)");
        $display("mode,cycles_per_op,ops_per_sec,gops_per_sec");
        $display("gf16_add,%0.2f,%0.0f,%0.2f", cycles_per_op_real[0], ops_per_sec_real[0], ops_per_sec_real[0] / 1e9);
        $display("gf16_mul,%0.2f,%0.0f,%0.2f", cycles_per_op_real[1], ops_per_sec_real[1], ops_per_sec_real[1] / 1e9);
        $display("tf3_add,%0.2f,%0.0f,%0.2f", cycles_per_op_real[2], ops_per_sec_real[2], ops_per_sec_real[2] / 1e9);
        $display("tf3_dot,%0.2f,%0.0f,%0.2f", cycles_per_op_real[3], ops_per_sec_real[3], ops_per_sec_real[3] / 1e9);

        $display("\n=== Benchmark complete ===");
        $finish;
    end

    // ============================================================================
    // BENCHMARK TASK
    // ============================================================================
    task run_benchmark;
        input [1:0] test_mode_val;
        input [79:0] mode_name_str;

        reg [31:0] test_a;
        reg [31:0] test_b;
        integer i;
        real clock_freq_mhz;
        real clock_period_ns;

        begin
            // Calculate clock metrics
            clock_freq_mhz = 1000.0 / `CLOCK_PERIOD;
            clock_period_ns = `CLOCK_PERIOD * 1.0;

            $display("Running benchmark for mode: %0s", mode_name_str);
            $display("  Target operations: %0d", `BENCH_OPS);

            // Setup mode and operands
            mode = test_mode_val;

            // Set appropriate operands based on mode
            case (test_mode_val)
                2'b00, 2'b01: begin  // GF16 modes
                    // GF16: test with 1.5 + 2.25 (GF16 encoded values)
                    test_a = {16'd0, 16'h3E66};  // ~1.5 in GF16
                    test_b = {16'd0, 16'h4012};  // ~2.25 in GF16
                end
                2'b10, 2'b11: begin  // TF3 modes
                    // TF3-9: test with non-zero trit values
                    test_a = {14'd0, 18'h12B40};  // Some TF3-9 value
                    test_b = {14'd0, 18'h10400};  // Another TF3-9 value
                end
            endcase

            in_a = test_a;
            in_b = test_b;

            // Start benchmark
            @(posedge clk);
            bench_enable = 1;

            // Feed N operations through the ALU
            // Handshake: in_valid → wait for in_ready → pulse → wait for out_valid
            for (i = 0; i < `BENCH_OPS; i = i + 1) begin
                timeout_counter = 0;

                // Wait for ready
                while (!in_ready && (timeout_counter < `TIMEOUT_CYCLES)) begin
                    @(posedge clk);
                    timeout_counter = timeout_counter + 1;
                end

                if (timeout_counter >= `TIMEOUT_CYCLES) begin
                    $display("ERROR: Timeout waiting for in_ready in mode %0s!", mode_name_str);
                    $finish;
                end

                // Pulse in_valid
                in_valid = 1;
                @(posedge clk);

                // Wait for output
                timeout_counter = 0;
                while (!out_valid && (timeout_counter < `TIMEOUT_CYCLES)) begin
                    @(posedge clk);
                    timeout_counter = timeout_counter + 1;
                end

                if (timeout_counter >= `TIMEOUT_CYCLES) begin
                    $display("ERROR: Timeout waiting for out_valid in mode %0s!", mode_name_str);
                    $finish;
                end

                in_valid = 0;
            end

            // Wait for benchmark completion
            timeout_counter = 0;
            while (!bench_result_done && (timeout_counter < `TIMEOUT_CYCLES)) begin
                @(posedge clk);
                timeout_counter = timeout_counter + 1;
            end

            if (timeout_counter >= `TIMEOUT_CYCLES) begin
                $display("ERROR: Benchmark completion timeout in mode %0s!", mode_name_str);
                $finish;
            end

            // Calculate metrics
            cycles_per_op_real[test_mode_val] = bench_result_cycle_count * 1.0 / bench_result_ops_done;
            ops_per_sec_real[test_mode_val] = clock_freq_mhz * 1e6 / cycles_per_op_real[test_mode_val];

            $display("  Results: cycles=%0d, ops=%0d, cycles/op=%.2f, ops/sec=%.0f",
                bench_result_cycle_count, bench_result_ops_done,
                cycles_per_op_real[test_mode_val], ops_per_sec_real[test_mode_val]);

            // Small delay between benchmarks
            #(10 * `CLOCK_PERIOD);
        end
    endtask

    // ============================================================================
    // TIMEOUT WATCHDOG
    // ============================================================================
    always @(posedge clk) begin
        if (rst_n && (timeout_counter > 0)) begin
            timeout_counter = timeout_counter + 1;
            if (timeout_counter > `TIMEOUT_CYCLES) begin
                $display("FATAL ERROR: Global timeout reached!");
                $finish;
            end
        end
    end

    // ============================================================================
    // WAVEFORM DUMP (optional, for debugging)
    // ============================================================================
    initial begin
        // Uncomment for waveform dump
        // $dumpfile("tb_bench_sacred.vcd");
        // $dumpvars(0, tb_bench_sacred);
    end

endmodule
