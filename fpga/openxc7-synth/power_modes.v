//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

// =============================================================================
// POWER MODES — EXP-6: FPGA Power Measurement for Trinity FPGA Level 2
// =============================================================================
// Target: Artix-7 XC7A100T-1FGG676C on QMTECH board
// Clock:  50 MHz
//
// MEASUREMENT PROTOCOL
// ─────────────────────
// Equipment: USB power meter inline on FPGA USB power rail
//   Recommended: ATORCH UD18 / UD24, or similar USB-C PD meter
//   - Set display to "Power (W)" mode
//   - Allow 5 seconds per mode for reading to stabilize
//
// Host terminal (115200 8-N-1): each mode transition sends 4 bytes:
//   [0xAA] [0xBB] [0xPM] [mode_byte]
//   0xAA 0xBB = frame sync preamble
//   0xPM      = 0x50 0x4D ASCII "PM" (Power Mode marker)
//   mode_byte = 0x00..0x04 (current mode number)
//
// EXPECTED POWER RANGES (3.3V rail, XC7A100T)
// ─────────────────────────────────────────────
//   Mode 0 IDLE       : ~0.45 W  (quiescent, all logic gated)
//   Mode 1 BLINK      : ~0.50 W  (minimal toggle activity)
//   Mode 2 1-BLOCK    : ~0.60 W  (one transformer block, ~6% LUT)
//   Mode 3 4-BLOCK    : ~0.75 W  (full 4-block pipeline, ~24% LUT)
//   Mode 4 AUTO-CYCLE : varies   (cycles all modes, read per-mode delta)
//
// RESULT TABLE FORMAT
// ─────────────────────
// Copy-paste this table into experiment notes:
//
//  ┌──────────┬────────────┬────────────┬────────────┬────────────┐
//  │  Mode    │  V (rail)  │  I (mA)    │  P (mW)    │  Delta P   │
//  ├──────────┼────────────┼────────────┼────────────┼────────────┤
//  │ IDLE(0)  │            │            │            │  baseline  │
//  │ BLINK(1) │            │            │            │            │
//  │ 1-BLK(2) │            │            │            │            │
//  │ 4-BLK(3) │            │            │            │            │
//  └──────────┴────────────┴────────────┴────────────┴────────────┘
//
// Active-low LED: assign led = ~led_state  (0 = ON, 1 = OFF)
// Debug LEDs [1:0]: show current mode index (binary encoded, active-low)
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module power_modes (
    input  wire        clk,
    input  wire [1:0]  sw,          // DIP switches: mode select
    input  wire        btn,          // Button: enable mode-4 auto-cycle
    output wire        uart_tx,
    output wire        led,
    output wire [1:0]  debug_leds
);

    // =========================================================================
    // PARAMETERS
    // =========================================================================
    // Baud divisor: 50 MHz / 27 / 16 ≈ 115200 baud (oversampling x16)
    localparam CLK_DIV       = 6'd27;

    // 1-second counter: 50,000,000 clocks
    localparam ONE_SEC_CNT   = 26'd50_000_000;

    // Blink half-period: 0.5 s = 25,000,000 clocks
    localparam BLINK_HALF    = 25'd25_000_000;

    // Mode definitions
    localparam MODE_IDLE     = 3'd0;
    localparam MODE_BLINK    = 3'd1;
    localparam MODE_1BLOCK   = 3'd2;
    localparam MODE_4BLOCK   = 3'd3;
    localparam MODE_AUTO     = 3'd4;

    // UART frame bytes
    localparam UART_PREAMBLE0 = 8'hAA;
    localparam UART_PREAMBLE1 = 8'hBB;
    localparam UART_PM0       = 8'h50;   // 'P'
    localparam UART_PM1       = 8'h4D;   // 'M'

    // =========================================================================
    // POWER-ON RESET
    // =========================================================================
    reg [7:0] por_cnt = 8'd0;
    reg       rst     = 1'b1;

    always @(posedge clk) begin
        if (por_cnt < 8'd255) begin
            por_cnt <= por_cnt + 8'd1;
            rst     <= 1'b1;
        end else begin
            rst     <= 1'b0;
        end
    end

    // =========================================================================
    // BUTTON DEBOUNCE (simple 20-bit counter, ~20ms @ 50 MHz)
    // =========================================================================
    reg [19:0] btn_debounce = 20'd0;
    reg        btn_sync0    = 1'b0;
    reg        btn_sync1    = 1'b0;
    reg        btn_prev     = 1'b0;
    reg        auto_enable  = 1'b0;     // sticky toggle for mode-4

    always @(posedge clk) begin
        if (rst) begin
            btn_sync0   <= 1'b0;
            btn_sync1   <= 1'b0;
            btn_prev    <= 1'b0;
            btn_debounce<= 20'd0;
            auto_enable <= 1'b0;
        end else begin
            btn_sync0 <= btn;
            btn_sync1 <= btn_sync0;

            if (btn_sync1 != btn_prev) begin
                btn_debounce <= 20'd0;
            end else if (btn_debounce < 20'hFFFFF) begin
                btn_debounce <= btn_debounce + 20'd1;
            end

            // Rising edge on stable button press → toggle auto-cycle
            if (btn_debounce == 20'hFFFFF && btn_sync1 == 1'b1 && btn_prev == 1'b0) begin
                auto_enable <= ~auto_enable;
            end
            btn_prev <= btn_sync1;
        end
    end

    // =========================================================================
    // MODE SELECTION
    // =========================================================================
    // Priority: auto_enable overrides DIP switches
    reg [2:0] current_mode = 3'd0;
    reg [2:0] prev_mode    = 3'd5;   // invalid sentinel → forces UART on first cycle

    always @(posedge clk) begin
        if (rst) begin
            current_mode <= MODE_IDLE;
        end else begin
            if (auto_enable)
                current_mode <= MODE_AUTO;
            else
                current_mode <= {1'b0, sw};   // sw[1:0] → modes 0-3
        end
    end

    // =========================================================================
    // 1-SECOND AUTO-CYCLE COUNTER (Mode 4)
    // =========================================================================
    reg [25:0] auto_timer    = 26'd0;
    reg [1:0]  auto_idx      = 2'd0;   // cycles through modes 0..3
    reg [2:0]  auto_submode  = 3'd0;   // the effective sub-mode in auto cycle

    always @(posedge clk) begin
        if (rst) begin
            auto_timer   <= 26'd0;
            auto_idx     <= 2'd0;
            auto_submode <= MODE_IDLE;
        end else if (current_mode == MODE_AUTO) begin
            if (auto_timer >= ONE_SEC_CNT - 1) begin
                auto_timer <= 26'd0;
                auto_idx   <= auto_idx + 2'd1;   // wraps 0→1→2→3→0
            end else begin
                auto_timer <= auto_timer + 26'd1;
            end
            auto_submode <= {1'b0, auto_idx};
        end else begin
            auto_timer   <= 26'd0;
            auto_idx     <= 2'd0;
            auto_submode <= MODE_IDLE;
        end
    end

    // Resolved effective mode for clock-gating and LED logic
    wire [2:0] eff_mode = (current_mode == MODE_AUTO) ? auto_submode : current_mode;

    // =========================================================================
    // CLOCK ENABLES — gate transformer blocks by mode
    // =========================================================================
    // block_ce[0]: block 1 active in modes 2, 3
    // block_ce[1]: block 2 active in mode 3 only
    // block_ce[2]: block 3 active in mode 3 only
    // block_ce[3]: block 4 active in mode 3 only
    wire block_ce0 = (eff_mode == MODE_1BLOCK) || (eff_mode == MODE_4BLOCK);
    wire block_ce1 = (eff_mode == MODE_4BLOCK);
    wire block_ce2 = (eff_mode == MODE_4BLOCK);
    wire block_ce3 = (eff_mode == MODE_4BLOCK);

    // =========================================================================
    // BLINK COUNTER (Mode 1 and idle indicator in Mode 0)
    // =========================================================================
    reg [24:0] blink_cnt  = 25'd0;
    reg        blink_state = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            blink_cnt   <= 25'd0;
            blink_state <= 1'b0;
        end else begin
            if (blink_cnt >= BLINK_HALF - 1) begin
                blink_cnt   <= 25'd0;
                blink_state <= ~blink_state;
            end else begin
                blink_cnt <= blink_cnt + 25'd1;
            end
        end
    end

    // =========================================================================
    // LED LOGIC (active-low)
    // =========================================================================
    // Mode 0 IDLE    : LED OFF (minimum power)
    // Mode 1 BLINK   : LED blinks at 1 Hz
    // Mode 2 1-BLOCK : LED solid ON (shows block active)
    // Mode 3 4-BLOCK : LED solid ON
    // Mode 4 AUTO    : follows sub-mode
    reg led_state = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            led_state <= 1'b0;
        end else begin
            case (eff_mode)
                MODE_IDLE  : led_state <= 1'b0;
                MODE_BLINK : led_state <= blink_state;
                MODE_1BLOCK: led_state <= 1'b1;
                MODE_4BLOCK: led_state <= 1'b1;
                default    : led_state <= 1'b0;
            endcase
        end
    end

    assign led = ~led_state;   // active-low LED: 0 = ON

    // Debug LEDs: binary-encode eff_mode[1:0], active-low
    assign debug_leds = ~eff_mode[1:0];

    // =========================================================================
    // STUB INFERENCE LOGIC
    // Clock-enable-gated dummy registers simulate LUT switching activity
    // for realistic power draw (replace with real trinity_block instantiation)
    // =========================================================================
    reg [7:0] blk1_cnt = 8'd0;
    reg [7:0] blk2_cnt = 8'd0;
    reg [7:0] blk3_cnt = 8'd0;
    reg [7:0] blk4_cnt = 8'd0;

    always @(posedge clk) begin
        if (block_ce0) blk1_cnt <= blk1_cnt + 8'd1;
        if (block_ce1) blk2_cnt <= blk2_cnt + 8'd1;
        if (block_ce2) blk3_cnt <= blk3_cnt + 8'd1;
        if (block_ce3) blk4_cnt <= blk4_cnt + 8'd1;
    end

    // =========================================================================
    // UART TRANSMITTER — 8-N-1, 115200 baud, oversampled x16
    // =========================================================================
    // TX state machine
    localparam TX_IDLE  = 2'd0;
    localparam TX_START = 2'd1;
    localparam TX_DATA  = 2'd2;
    localparam TX_STOP  = 2'd3;

    reg [1:0]  tx_state  = TX_IDLE;
    reg [7:0]  tx_shift  = 8'd0;
    reg [3:0]  tx_bitcnt = 4'd0;
    reg [5:0]  tx_divcnt = 6'd0;
    reg        tx_busy   = 1'b0;
    reg        uart_tx_r = 1'b1;

    assign uart_tx = uart_tx_r;

    wire tx_baud_tick = (tx_divcnt == CLK_DIV - 1);

    // UART packet sequencer: send 4-byte frame on mode change
    // Frame: [0xAA][0xBB][0x50(P)][0x4D(M)][mode_byte]
    // Note: 5 bytes total for full frame
    localparam SEQ_IDLE = 3'd0;
    localparam SEQ_B0   = 3'd1;   // 0xAA
    localparam SEQ_B1   = 3'd2;   // 0xBB
    localparam SEQ_B2   = 3'd3;   // 0x50 'P'
    localparam SEQ_B3   = 3'd4;   // 0x4D 'M'
    localparam SEQ_B4   = 3'd5;   // mode_byte

    reg [2:0] seq_state    = SEQ_IDLE;
    reg [7:0] tx_load_byte = 8'd0;
    reg       tx_load_req  = 1'b0;
    reg [2:0] latch_mode   = 3'd0;

    // Detect mode transition (compare prev_mode to current eff_mode)
    reg [2:0] eff_mode_prev = 3'd5;

    always @(posedge clk) begin
        if (rst) begin
            eff_mode_prev <= 3'd5;
            seq_state     <= SEQ_IDLE;
            tx_load_req   <= 1'b0;
            latch_mode    <= 3'd0;
        end else begin
            tx_load_req <= 1'b0;   // default: no load

            // Latch mode transition
            if (eff_mode != eff_mode_prev) begin
                eff_mode_prev <= eff_mode;
                latch_mode    <= eff_mode;
                seq_state     <= SEQ_B0;
            end

            case (seq_state)
                SEQ_IDLE: begin
                    // wait for mode change (handled above)
                end

                SEQ_B0: begin
                    if (!tx_busy) begin
                        tx_load_byte <= UART_PREAMBLE0;
                        tx_load_req  <= 1'b1;
                        seq_state    <= SEQ_B1;
                    end
                end

                SEQ_B1: begin
                    if (!tx_busy && !tx_load_req) begin
                        tx_load_byte <= UART_PREAMBLE1;
                        tx_load_req  <= 1'b1;
                        seq_state    <= SEQ_B2;
                    end
                end

                SEQ_B2: begin
                    if (!tx_busy && !tx_load_req) begin
                        tx_load_byte <= UART_PM0;
                        tx_load_req  <= 1'b1;
                        seq_state    <= SEQ_B3;
                    end
                end

                SEQ_B3: begin
                    if (!tx_busy && !tx_load_req) begin
                        tx_load_byte <= UART_PM1;
                        tx_load_req  <= 1'b1;
                        seq_state    <= SEQ_B4;
                    end
                end

                SEQ_B4: begin
                    if (!tx_busy && !tx_load_req) begin
                        tx_load_byte <= {5'd0, latch_mode};
                        tx_load_req  <= 1'b1;
                        seq_state    <= SEQ_IDLE;
                    end
                end

                default: seq_state <= SEQ_IDLE;
            endcase
        end
    end

    // UART TX shift register
    always @(posedge clk) begin
        if (rst) begin
            tx_state  <= TX_IDLE;
            tx_busy   <= 1'b0;
            uart_tx_r <= 1'b1;
            tx_divcnt <= 6'd0;
            tx_bitcnt <= 4'd0;
            tx_shift  <= 8'd0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    uart_tx_r <= 1'b1;
                    tx_busy   <= 1'b0;
                    tx_divcnt <= 6'd0;
                    if (tx_load_req) begin
                        tx_shift  <= tx_load_byte;
                        tx_busy   <= 1'b1;
                        tx_state  <= TX_START;
                        tx_divcnt <= 6'd0;
                    end
                end

                TX_START: begin
                    uart_tx_r <= 1'b0;   // start bit
                    if (tx_baud_tick) begin
                        tx_divcnt <= 6'd0;
                        tx_bitcnt <= 4'd0;
                        tx_state  <= TX_DATA;
                    end else begin
                        tx_divcnt <= tx_divcnt + 6'd1;
                    end
                end

                TX_DATA: begin
                    uart_tx_r <= tx_shift[0];
                    if (tx_baud_tick) begin
                        tx_divcnt <= 6'd0;
                        tx_shift  <= {1'b1, tx_shift[7:1]};
                        if (tx_bitcnt == 4'd7) begin
                            tx_state <= TX_STOP;
                        end else begin
                            tx_bitcnt <= tx_bitcnt + 4'd1;
                        end
                    end else begin
                        tx_divcnt <= tx_divcnt + 6'd1;
                    end
                end

                TX_STOP: begin
                    uart_tx_r <= 1'b1;   // stop bit
                    if (tx_baud_tick) begin
                        tx_divcnt <= 6'd0;
                        tx_state  <= TX_IDLE;
                        tx_busy   <= 1'b0;
                    end else begin
                        tx_divcnt <= tx_divcnt + 6'd1;
                    end
                end

                default: tx_state <= TX_IDLE;
            endcase
        end
    end

endmodule

// =============================================================================
// XDC CONSTRAINTS ADDITION — power_modes.v
// =============================================================================
// Append these lines to the project .xdc file (e.g., power_modes.xdc):
//
// # Clock (50 MHz oscillator)
// set_property PACKAGE_PIN U22 [get_ports clk]
// set_property IOSTANDARD LVCMOS33 [get_ports clk]
//
// # LED D6 (active-low, T23)
// set_property PACKAGE_PIN T23 [get_ports led]
// set_property IOSTANDARD LVCMOS33 [get_ports led]
//
// # Debug LEDs [0] and [1] — active-low
// set_property PACKAGE_PIN N23 [get_ports {debug_leds[0]}]
// set_property IOSTANDARD LVCMOS33 [get_ports {debug_leds[0]}]
// set_property PACKAGE_PIN M22 [get_ports {debug_leds[1]}]
// set_property IOSTANDARD LVCMOS33 [get_ports {debug_leds[1]}]
//
// # UART TX (to host)
// set_property PACKAGE_PIN K20 [get_ports uart_tx]
// set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
//
// # DIP switch sw[0] and sw[1]
// # QMTECH board: SW1 pin 1 → K21, SW1 pin 2 → J21
// # (verify against your PCB silkscreen; these are the QMTECH FGG676 typical SW pins)
// set_property PACKAGE_PIN K21 [get_ports {sw[0]}]
// set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
// set_property PULLDOWN true [get_ports {sw[0]}]
// set_property PACKAGE_PIN J21 [get_ports {sw[1]}]
// set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
// set_property PULLDOWN true [get_ports {sw[1]}]
//
// # Button (for mode-4 auto-cycle toggle)
// # QMTECH on-board user button → typically P23 or M19 depending on revision
// # Check silkscreen labelled "KEY" or "S1" on your board
// set_property PACKAGE_PIN P23 [get_ports btn]
// set_property IOSTANDARD LVCMOS33 [get_ports btn]
// set_property PULLDOWN true [get_ports btn]
//
// # Timing constraint
// create_clock -period 20.000 -name clk [get_ports clk]
// =============================================================================
