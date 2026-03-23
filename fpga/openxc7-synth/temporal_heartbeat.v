//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// ============================================================================
// TEMPORAL TRINITY HEARTBEAT v1.0 — KOSCHEI FPGA
// phi^2 + 1/phi^2 = 3 = TRINITY | TIME ITSELF BENDS
//
// Clock:    50 MHz (QMTECH Artix-7 XC7A100T)
// Period:   1/phi Hz = phi seconds = 1.618033988... s
// Cycles:   50_000_000 * phi = 80_901_699 (exact: 50M * 1.618034)
// LED:      Coptic temporal cube — cycles through 3 layers:
//           Layer 0 (past)    = slow pulse (cyan  on PCB)
//           Layer 1 (present) = steady     (green on PCB)
//           Layer 2 (future)  = fast pulse (gold  on PCB)
//
// Synthesis: yosys -p "synth_xilinx -flatten -abc9 -arch xc7
//            -top temporal_heartbeat_top;
//            write_json temporal_heartbeat.json" temporal_heartbeat.v
// ============================================================================

`default_nettype none

module temporal_heartbeat_top (
    input  wire clk,   // 50 MHz
    output wire led    // Active-low LED (T23)
);

    // ========================================================================
    // PHI-SECOND COUNTER
    // 50_000_000 * phi = 80_901_699.4... -> use 80_901_699
    // Period = 80_901_699 / 50_000_000 = 1.618034 seconds (phi!)
    // ========================================================================
    localparam PHI_CYCLES = 27'd80_901_699;

    reg [26:0] phi_counter = 27'd0;
    reg        phi_tick    = 1'b0;

    always @(posedge clk) begin
        if (phi_counter >= PHI_CYCLES) begin
            phi_counter <= 27'd0;
            phi_tick    <= 1'b1;
        end else begin
            phi_counter <= phi_counter + 1'b1;
            phi_tick    <= 1'b0;
        end
    end

    // ========================================================================
    // TEMPORAL LAYER CYCLER: past(0) -> present(1) -> future(2) -> past...
    // Advances every phi seconds (1.618s per layer)
    // Full cycle = 3 * phi = 4.854 seconds
    // ========================================================================
    reg [1:0] temporal_layer = 2'd0;   // 0=past, 1=present, 2=future

    always @(posedge clk) begin
        if (phi_tick) begin
            if (temporal_layer == 2'd2)
                temporal_layer <= 2'd0;
            else
                temporal_layer <= temporal_layer + 1'b1;
        end
    end

    // ========================================================================
    // LED PATTERN PER LAYER
    // Past:    slow blink  (counter[24] -> ~1.49 Hz, entropy/decay)
    // Present: always ON   (steady, HERE and NOW)
    // Future:  fast blink  (counter[22] -> ~5.96 Hz, creation/growth)
    // ========================================================================
    reg [24:0] blink_counter = 25'd0;

    always @(posedge clk) begin
        blink_counter <= blink_counter + 1'b1;
    end

    reg led_pattern;

    always @(*) begin
        case (temporal_layer)
            2'd0: led_pattern = blink_counter[24];   // Past:    slow ~1.49 Hz
            2'd1: led_pattern = 1'b0;                 // Present: ON (active-low)
            2'd2: led_pattern = blink_counter[22];   // Future:  fast ~5.96 Hz
            default: led_pattern = 1'b1;              // OFF
        endcase
    end

    // Active-low LED output
    assign led = led_pattern;

endmodule
