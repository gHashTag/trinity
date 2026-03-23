//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY RISC-V BLINK — Simple State Machine LED Blinker
// ═══════════════════════════════════════════════════════════════════════════════
//
// Demonstrates autonomous FPGA operation without external programming.
// Uses a simple state machine to blink LED in multiple patterns.
//
// ═══════════════════════════════════════════════════════════════════════════════

module trinity_top (
    input  wire clk,    // 50 MHz oscillator @ U22
    output wire led     // LED D5 @ T23 (active LOW)
);

    //==========================================================================
    // STATE MACHINE
    //==========================================================================
    localparam STATE_IDLE     = 3'd0;
    localparam STATE_BLINK_ON = 3'd1;
    localparam STATE_BLINK_OFF = 3'd2;
    localparam STATE_PATTERN   = 3'd3;
    localparam STATE_CHAOTIC  = 3'd4;

    reg [2:0] state, next_state;

    //==========================================================================
    // COUNTERS
    //==========================================================================
    // 50 MHz / 2^26 = ~0.75 Hz (slow blink)
    // 50 MHz / 2^24 = ~3 Hz (medium blink)
    // 50 MHz / 2^20 = ~48 Hz (fast blink)

    reg [25:0] counter;
    reg [19:0] fast_counter;
    reg [31:0] lfsr;  // Linear Feedback Shift Register for pseudo-random

    // LFSR for chaotic mode (32-bit Xorshift variant)
    wire [31:0] lfsr_next;
    assign lfsr_next = {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};

    always @(posedge clk) begin
        counter <= counter + 1'd1;
        fast_counter <= fast_counter + 1'd1;
        lfsr <= lfsr_next;
    end

    //==========================================================================
    // MODE DETECTION
    //==========================================================================
    // Auto-cycle through modes every ~2 seconds (50MHz * 2^26)
    wire mode_change = (counter == 26'd0);
    reg [1:0] mode;
    always @(posedge clk) begin
        if (mode_change)
            mode <= mode + 1'd1;
    end

    //==========================================================================
    // STATE MACHINE LOGIC
    //==========================================================================
    reg led_int;

    always @(*) begin
        case (mode)
            2'd0: begin  // Slow blink (~0.75 Hz)
                led_int = counter[25];
            end
            2'd1: begin  // Fast blink (~48 Hz)
                led_int = fast_counter[19];
            end
            2'd2: begin  // Chaotic (LFSR-based)
                led_int = lfsr[20] ^ lfsr[10] ^ lfsr[5];
            end
            default: led_int = 1'b0;
        endcase
    end

    //==========================================================================
    // LED OUTPUT (active LOW)
    //==========================================================================
    assign led = ~led_int;  // Invert for active-low LED

    //==========================================================================
    // INITIALIZATION
    //==========================================================================
    initial begin
        state = STATE_IDLE;
        counter = 26'd0;
        fast_counter = 20'd0;
        lfsr = 32'hDEAD_BEEF;  // Seed value
    end

endmodule
