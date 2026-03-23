// ============================================================================
// TEMPORAL TRINITY HEARTBEAT — iCE40 HX8K / UP5K
// phi^2 + 1/phi^2 = 3 = TRINITY | TIME ITSELF BENDS
//
// Clock:    12 MHz (iCE40 HX8K-EVB / UP5K breakout)
// Period:   1/phi Hz = phi seconds = 1.618033988... s
// Cycles:   12_000_000 * phi = 19,416,408 (exact: 12M * 1.618034)
// Counter:  25 bits (2^25 = 33,554,432 > 19,416,408)
//
// LED:      Coptic temporal cube — cycles through 3 layers:
//           Layer 0 (past)    = slow pulse (1.49 Hz)
//           Layer 1 (present) = steady ON
//           Layer 2 (future)  = fast pulse (5.96 Hz)
//
// Synthesis: yosys -p "synth_ice40 -top temporal_heartbeat_ice40;
//            write_json temporal_heartbeat_ice40.json" temporal_heartbeat_ice40.v
// Flash:     iceprog temporal_heartbeat_ice40.bin
// ============================================================================

`default_nettype none

module temporal_heartbeat_ice40 (
    input  wire clk,   // 12 MHz
    output wire led    // Active-high LED (accent: active-low on some boards)
);

    // ========================================================================
    // PHI-SECOND COUNTER (iCE40 @ 12 MHz)
    // 12_000_000 * phi = 19,416,408 (rounded)
    // Period = 19,416,408 / 12,000,000 = 1.618034 seconds
    // ========================================================================
    localparam PHI_CYCLES = 25'd19_416_408;

    reg [24:0] phi_counter = 25'd0;
    reg        phi_tick    = 1'b0;

    always @(posedge clk) begin
        if (phi_counter >= PHI_CYCLES) begin
            phi_counter <= 25'd0;
            phi_tick    <= 1'b1;
        end else begin
            phi_counter <= phi_counter + 1'b1;
            phi_tick    <= 1'b0;
        end
    end

    // ========================================================================
    // TEMPORAL LAYER CYCLER: past(0) -> present(1) -> future(2)
    // ========================================================================
    reg [1:0] temporal_layer = 2'd0;

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
    // ========================================================================
    reg [22:0] blink_counter = 23'd0;

    always @(posedge clk) begin
        blink_counter <= blink_counter + 1'b1;
    end

    reg led_out;

    always @(*) begin
        case (temporal_layer)
            2'd0: led_out = blink_counter[22];   // Past:    slow ~1.43 Hz
            2'd1: led_out = 1'b1;                 // Present: ON
            2'd2: led_out = blink_counter[20];   // Future:  fast ~5.72 Hz
            default: led_out = 1'b0;
        endcase
    end

    assign led = led_out;

endmodule
