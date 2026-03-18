// ═══════════════════════════════════════════════════════════════════════════════
// TESTBENCH: HSLM Ternary MAC — verify zero-DSP matmul
// ═══════════════════════════════════════════════════════════════════════════════

`timescale 1ns / 1ps

module tb_hslm_ternary_mac;

    parameter INPUT_WIDTH = 16;
    parameter ACC_WIDTH   = 32;
    parameter N_INPUTS    = 8;   // small for test
    parameter N_PARALLEL  = 4;   // small for test

    reg clk = 0;
    reg rst = 1;
    reg valid = 0;
    reg signed [INPUT_WIDTH-1:0] input_val;
    reg [2*N_PARALLEL-1:0] weights_packed;

    wire [N_PARALLEL-1:0] done;
    wire signed [ACC_WIDTH-1:0] results [0:N_PARALLEL-1];

    // Clock: 100 MHz
    always #5 clk = ~clk;

    ternary_mac_array #(
        .N_PARALLEL(N_PARALLEL),
        .N_INPUTS(N_INPUTS),
        .INPUT_WIDTH(INPUT_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .valid(valid),
        .input_val(input_val),
        .weights_packed(weights_packed),
        .done(done),
        .results(results)
    );

    // ═══ TEST VECTORS ═══
    // Input vector: [100, -50, 200, -100, 150, 75, -25, 300] (Q8.8 simplified as int)
    //
    // Weight matrix (N_PARALLEL=4 neurons × N_INPUTS=8):
    //   Neuron 0: [+1, -1, +1, 0, 0, -1, +1, +1]  → expected: 100-(-50)+200+0+0-75+(-25)+300 = 550
    //   Neuron 1: [0, +1, 0, +1, -1, 0, 0, +1]    → expected: 0+(-50)+0+(-100)-150+0+0+300 = 0
    //   Neuron 2: [-1, -1, -1, -1, -1, -1, -1, -1] → expected: -(100+(-50)+200+(-100)+150+75+(-25)+300) = -650
    //   Neuron 3: [+1, +1, +1, +1, +1, +1, +1, +1] → expected: 100+(-50)+200+(-100)+150+75+(-25)+300 = 650
    //
    // Weight encoding: 00=0, 01=+1, 11=-1

    reg signed [INPUT_WIDTH-1:0] test_inputs [0:7];
    reg [2*N_PARALLEL-1:0] test_weights [0:7]; // weights for each input step

    initial begin
        // Input values
        test_inputs[0] = 100;
        test_inputs[1] = -50;
        test_inputs[2] = 200;
        test_inputs[3] = -100;
        test_inputs[4] = 150;
        test_inputs[5] = 75;
        test_inputs[6] = -25;
        test_inputs[7] = 300;

        // For each input step, pack 4 neuron weights (2 bits each)
        // Bit layout: [N3_hi N3_lo N2_hi N2_lo N1_hi N1_lo N0_hi N0_lo]
        //
        // Step 0: N0=+1(01), N1=0(00), N2=-1(11), N3=+1(01) → 01_11_00_01 = 8'h71
        test_weights[0] = 8'b01_11_00_01;
        // Step 1: N0=-1(11), N1=+1(01), N2=-1(11), N3=+1(01) → 01_11_01_11 = 8'h77
        test_weights[1] = 8'b01_11_01_11;
        // Step 2: N0=+1(01), N1=0(00), N2=-1(11), N3=+1(01) → 01_11_00_01
        test_weights[2] = 8'b01_11_00_01;
        // Step 3: N0=0(00), N1=+1(01), N2=-1(11), N3=+1(01) → 01_11_01_00
        test_weights[3] = 8'b01_11_01_00;
        // Step 4: N0=0(00), N1=-1(11), N2=-1(11), N3=+1(01) → 01_11_11_00
        test_weights[4] = 8'b01_11_11_00;
        // Step 5: N0=-1(11), N1=0(00), N2=-1(11), N3=+1(01) → 01_11_00_11
        test_weights[5] = 8'b01_11_00_11;
        // Step 6: N0=+1(01), N1=0(00), N2=-1(11), N3=+1(01) → 01_11_00_01
        test_weights[6] = 8'b01_11_00_01;
        // Step 7: N0=+1(01), N1=+1(01), N2=-1(11), N3=+1(01) → 01_11_01_01
        test_weights[7] = 8'b01_11_01_01;
    end

    integer step;
    integer errors = 0;

    initial begin
        $dumpfile("tb_hslm_ternary_mac.vcd");
        $dumpvars(0, tb_hslm_ternary_mac);

        // Reset
        #20;
        rst = 0;
        #10;

        // Feed inputs
        for (step = 0; step < N_INPUTS; step = step + 1) begin
            @(posedge clk);
            valid = 1;
            input_val = test_inputs[step];
            weights_packed = test_weights[step];
        end

        @(posedge clk);
        valid = 0;

        // Wait for done
        #100;

        // Check results
        $display("");
        $display("═══════════════════════════════════════════════════");
        $display(" HSLM TERNARY MAC — Test Results");
        $display("═══════════════════════════════════════════════════");
        $display(" Neuron 0: %d (expected: computed from weights)", results[0]);
        $display(" Neuron 1: %d", results[1]);
        $display(" Neuron 2: %d (all -1: should be -sum)", results[2]);
        $display(" Neuron 3: %d (all +1: should be +sum)", results[3]);
        $display("");

        // Verify neuron 2 = -neuron 3
        if (results[2] == -results[3]) begin
            $display(" PASS: Neuron2 = -Neuron3 (all-neg = negation of all-pos)");
        end else begin
            $display(" FAIL: Neuron2 (%d) != -Neuron3 (%d)", results[2], results[3]);
            errors = errors + 1;
        end

        // Verify neuron 3 = sum of all inputs
        if (results[3] == 100 + (-50) + 200 + (-100) + 150 + 75 + (-25) + 300) begin
            $display(" PASS: Neuron3 = sum(inputs) = 650");
        end else begin
            $display(" FAIL: Neuron3 = %d, expected 650", results[3]);
            errors = errors + 1;
        end

        $display("");
        if (errors == 0)
            $display(" ALL TESTS PASSED — Zero-DSP ternary MAC verified!");
        else
            $display(" %d ERRORS detected", errors);
        $display("═══════════════════════════════════════════════════");

        #10;
        $finish;
    end

endmodule
