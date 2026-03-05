// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  TRINITY V2 — Beautiful Waiting Mode (Morse "TRINITY" + Breathing)         ║
// ║                                                                              ║
// ║  LED Effects while waiting for UART/JTAG connection:                       ║
// ║  1. Breathing (smooth pulse using φ-based timing)                          ║
// ║  2. Heartbeat (flash every φ seconds)                                     ║
// ║  3. Morse code "TRINITY" (every 10 seconds)                                ║
// ║                                                                              ║
// ║  Morse: TRINITY = - .-. .. -. .. - -.-- -                                 ║
// ║         T       R     I    N   I    T    Y                                  ║
// ║                                                                              ║
// ║  Golden Identity: φ² + 1/φ² = 3                                             ║
// ╚════════════════════════════════════════════════════════════════════════════╝

`timescale 1ns / 1ps
`default_nettype none

//==============================================================================
// MORSE CODE ENCODER
//==============================================================================
// TRINITY in Morse: - .-. .. -. .. - -.-- -
//
// T  -    dash
// R  .-.  dot-dash-dot
// I  ..   dot-dot
// N  -.   dot-dash
// I  ..   dot-dot
// T  -    dash
// Y  -.-- dash-dot-dot-dash
//
// Timing (standard): dot = 1 unit, dash = 3 units, gap = 1 unit, letter gap = 3 units

module MorseEncoder (
    input  wire clk,
    input  wire rst_n,
    input  wire enable,

    output reg  led_out,
    output reg  busy,
    output wire [3:0] letter_index  // Which letter we're transmitting
);

    // Morse timing at 50MHz
    // Standard dot = 100ms, dash = 300ms, gap = 100ms, letter gap = 300ms
    localparam DOT_DIV = 24'd5_000_000;     // 100ms @ 50MHz
    localparam DASH_DIV = 24'd15_000_000;    // 300ms
    localparam GAP_DIV = 24'd5_000_000;      // 100ms
    localparam LETTER_DIV = 24'd15_000_000;  // 300ms

    // TRINITY Morse code (encoded as sequence)
    // Format: {duration[1:0], symbol}
    // duration: 2'b00 = 100ms (dot/gap), 2'b01 = 300ms (dash/letter gap)
    // symbol: 1'b0 = off (gap), 1'b1 = on (dot/dash)
    localparam TOTAL_SYMBOLS = 26;  // 7 letters × ~3-4 symbols each

    reg [5:0] symbol_index;
    reg [1:0] duration_counter;
    reg [23:0] timer;
    reg transmitting;
    reg [3:0] letter_counter;

    // TRINITY Morse sequence
    // T: - (dash, off)
    // R: .-. (dot, dash, dot)
    // I: .. (dot, dot)
    // N: -. (dot, dash)
    // I: .. (dot, dot)
    // T: - (dash)
    // Y: -.-- (dash, dot, dot, dash)

    function [2:0] get_morse_symbol;
        input [5:0] idx;
        begin
            case (idx)
                // T: dash
                0: get_morse_symbol = 2'b11;   // ON, 300ms
                1: get_morse_symbol = 2'b00;   // OFF, 100ms

                // R: dot-dash-dot
                2: get_morse_symbol = 2'b01;   // ON, 100ms (dot)
                3: get_morse_symbol = 2'b00;   // OFF, 100ms
                4: get_morse_symbol = 2'b11;   // ON, 300ms (dash)
                5: get_morse_symbol = 2'b00;   // OFF, 100ms
                6: get_morse_symbol = 2'b01;   // ON, 100ms (dot)
                7: get_morse_symbol = 2'b10;   // OFF, 300ms (letter gap)

                // I: dot-dot
                8: get_morse_symbol = 2'b01;   // ON, 100ms
                9: get_morse_symbol = 2'b00;   // OFF, 100ms
                10: get_morse_symbol = 2'b01;  // ON, 100ms
                11: get_morse_symbol = 2'b10;  // OFF, 300ms

                // N: dot-dash
                12: get_morse_symbol = 2'b01;  // ON, 100ms
                13: get_morse_symbol = 2'b00;  // OFF, 100ms
                14: get_morse_symbol = 2'b11;  // ON, 300ms
                15: get_morse_symbol = 2'b10;  // OFF, 300ms

                // I: dot-dot
                16: get_morse_symbol = 2'b01;  // ON, 100ms
                17: get_morse_symbol = 2'b00;  // OFF, 100ms
                18: get_morse_symbol = 2'b01;  // ON, 100ms
                19: get_morse_symbol = 2'b10;  // OFF, 300ms

                // T: dash
                20: get_morse_symbol = 2'b11;  // ON, 300ms
                21: get_morse_symbol = 2'b10;  // OFF, 300ms

                // Y: dash-dot-dot-dash
                22: get_morse_symbol = 2'b11;  // ON, 300ms
                23: get_morse_symbol = 2'b00;  // OFF, 100ms
                24: get_morse_symbol = 2'b01;  // ON, 100ms
                25: get_morse_symbol = 2'b00;  // OFF, 100ms

                // End of sequence
                default: get_morse_symbol = 2'b10;  // OFF, 300ms
            endcase
        end
    endfunction

    // State machine
    localparam IDLE = 1'b0;
    localparam TRANSMIT = 1'b1;

    reg state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            symbol_index <= 6'd0;
            timer <= 24'd0;
            led_out <= 1'b0;
            busy <= 1'b0;
            transmitting <= 1'b0;
            letter_counter <= 4'd0;
            duration_counter <= 2'b00;
        end else begin
            // Start transmission on enable
            if (enable && state == IDLE) begin
                state <= TRANSMIT;
                symbol_index <= 6'd0;
                timer <= 24'd0;
                busy <= 1'b1;
                transmitting <= 1'b1;
                letter_counter <= 4'd0;
            end

            if (state == TRANSMIT) begin
                // Get current symbol
                if (timer == 24'd0) begin
                    // Load new symbol
                    {duration_counter, led_out} <= get_morse_symbol(symbol_index);

                    // Set timer based on duration
                    case (duration_counter)
                        2'b00: timer <= DOT_DIV;      // 100ms
                        2'b01: timer <= DOT_DIV;      // 100ms
                        2'b10: timer <= LETTER_DIV;   // 300ms
                        2'b11: timer <= DASH_DIV;     // 300ms
                    endcase

                    // Update counters
                    if (symbol_index < TOTAL_SYMBOLS - 1)
                        symbol_index <= symbol_index + 1;
                    else begin
                        // Transmission complete
                        state <= IDLE;
                        busy <= 1'b0;
                        transmitting <= 1'b0;
                        symbol_index <= 6'd0;
                        letter_counter <= 4'd0;
                    end

                    // Track letter progress
                    if (duration_counter == 2'b10)  // Letter gap
                        letter_counter <= letter_counter + 1;

                end else begin
                    timer <= timer - 1;
                end
            end
        end
    end

    assign letter_index = letter_counter;

endmodule

//==============================================================================
// BREATHING LED EFFECT (φ-based timing)
//==============================================================================
// Smooth pulse using sine-like approximation
// Period = φ² seconds ≈ 2.618 seconds

module BreathingLED (
    input  wire clk,
    input  wire rst_n,
    input  wire enable,

    output reg  led_out
);

    // Φ² = 2.618... → use 2.6 seconds for breathing cycle
    // 50MHz × 2.6 = ~130,000,000 cycles
    localparam BREATH_PERIOD = 24'd130_000_000;

    // Use 256 steps for smooth breathing
    reg [27:0] counter;
    reg [7:0] phase;
    wire [7:0] brightness;

    // Phase increment (completes 256 steps in BREATH_PERIOD)
    localparam PHASE_INC = BREATH_PERIOD / 256;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 28'd0;
            phase <= 8'd0;
            led_out <= 1'b0;
        end else if (enable) begin
            counter <= counter + 1;

            // Increment phase
            if (counter >= PHASE_INC - 1) begin
                counter <= 28'd0;
                phase <= phase + 1;
            end
        end
    end

    // Sine-like brightness using simple approximation
    // brightness = (sin(2π × phase/256) + 1) × 127.5
    // Approximation: abs(phase - 128) → invert for sine wave

    reg [15:0] sine_value;

    always @(*) begin
        // Triangle wave approximation of sine
        if (phase < 128)
            sine_value = phase * 2;  // 0 to 254 rising
        else
            sine_value = (256 - phase) * 2;  // 254 to 0 falling
    end

    // Threshold for LED on
    always @(*) begin
        // Use lower bits for threshold comparison (PWM-like effect)
        led_out = (counter[7:0] < sine_value[15:8]);
    end

endmodule

//==============================================================================
// HEARTBEAT (φ-second flash)
//==============================================================================
// Flash every φ seconds (1.618 seconds)

module Heartbeat (
    input  wire clk,
    input  wire rst_n,
    input  wire enable,

    output reg  led_out,
    output reg  flash_tick
);

    // φ = 1.618... → use 1.6 seconds
    // 50MHz × 1.6 = 80,000,000 cycles
    localparam PHI_PERIOD = 24'd80_000_000;

    reg [27:0] counter;
    reg [2:0] flash_length;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 28'd0;
            led_out <= 1'b0;
            flash_tick <= 1'b0;
            flash_length <= 3'd0;
        end else if (enable) begin
            flash_tick <= 1'b0;

            if (counter >= PHI_PERIOD - 1) begin
                counter <= 28'd0;
                flash_tick <= 1'b1;       // Trigger flash
                led_out <= 1'b1;
                flash_length <= 3'd5;      // Flash for ~5 cycles
            end else begin
                counter <= counter + 1;

                if (flash_length > 0) begin
                    flash_length <= flash_length - 1;
                    if (flash_length == 1)
                        led_out <= 1'b0;
                end
            end
        end
    end

endmodule

//==============================================================================
// TRINITY V2 TOP — BEAUTIFUL WAITING MODE
//==============================================================================

module trinity_v2_breathing (
    input  wire clk,
    input  wire rst,

    // UART (not used in waiting mode, but kept for compatibility)
    input  wire uart_rx,
    output wire uart_tx,

    // Status LEDs
    output wire led_d5,     // Breathing
    output wire led_d6,     // Heartbeat
    output wire led_d7      // Morse output
);

    // Reset synchronization
    reg [2:0] rst_sync;
    wire rst_n = ~rst_sync[2];

    always @(posedge clk) begin
        rst_sync <= {rst_sync[1:0], rst};
    end

    // UART detection (disable special effects when UART active)
    reg uart_detected;
    reg [23:0] uart_timeout;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_detected <= 1'b0;
            uart_timeout <= 24'd0;
        end else begin
            // Detect UART RX activity
            if (!uart_rx) begin
                uart_detected <= 1'b1;
                uart_timeout <= 24'd0;
            end else if (uart_detected) begin
                uart_timeout <= uart_timeout + 1;
                // Timeout after ~0.3 seconds of inactivity
                if (uart_timeout >= 24'd15_000_000) begin
                    uart_detected <= 1'b0;
                end
            end
        end
    end

    // Enable signals (disable effects when UART is active)
    wire enable = !uart_detected;

    // Morse encoder (every 10 seconds)
    reg [27:0] morse_timer;
    wire morse_trigger;
    wire morse_busy;

    // 10 seconds = 500,000,000 cycles @ 50MHz
    localparam MORSE_PERIOD = 28'd500_000_000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            morse_timer <= 28'd0;
        end else if (enable) begin
            if (morse_timer >= MORSE_PERIOD - 1) begin
                morse_timer <= 28'd0;
            end else begin
                morse_timer <= morse_timer + 1;
            end
        end
    end

    assign morse_trigger = (morse_timer == 28'd0) && enable;

    // Instantiate modules
    wire breathing_led;
    wire heartbeat_led;
    wire heartbeat_tick;
    wire morse_led;

    BreathingLED breathing (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable && !morse_busy),  // Pause breathing during Morse
        .led_out(breathing_led)
    );

    Heartbeat heartbeat (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .led_out(heartbeat_led),
        .flash_tick(heartbeat_tick)
    );

    MorseEncoder morse (
        .clk(clk),
        .rst_n(rst_n),
        .enable(morse_trigger),
        .led_out(morse_led),
        .busy(morse_busy),
        .letter_index()
    );

    // LED outputs
    // D5: Breathing (smooth pulse)
    assign led_d5 = uart_detected ? 1'b0 : breathing_led;

    // D6: Heartbeat (φ-second flash)
    assign led_d6 = uart_detected ? 1'b1 : heartbeat_led;

    // D7: Morse code output
    assign led_d7 = morse_led;

    // UART passthrough (loopback for testing)
    assign uart_tx = uart_rx;

endmodule

// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  WAITING MODE TIMING SUMMARY                                                 ║
// ╠════════════════════════════════════════════════════════════════════════════╣
// ║  Effect       | Period  | Description                                      ║
// ║  ──────────────────────────────────────────────────────────────────────  ║
// ║  Breathing    | 2.6s    | Smooth sine-like pulse (φ²)                         ║
// ║  Heartbeat    | 1.6s    | Single flash every φ seconds                       ║
// ║  Morse "TRINITY" | 10s   | Full message repeats every 10 seconds             ║
// ╚════════════════════════════════════════════════════════════════════════════╝

// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  VIDEO SHOTLIST (30-60 seconds)                                              ║
// ╠════════════════════════════════════════════════════════════════════════════╣
// ║  1. (0-5s) Show FPGA board on desk                                       ║
// ║  2. (5-10s) Zoom in on LEDs (show breathing effect)                       ║
// ║  3. (10-15s) Show heartbeat (flash every ~1.6s)                          ║
// ║  4. (15-25s) Wait for Morse (TRINITY in dashes/dots)                     ║
// ║  5. (25-30s) Text overlay: "TRINITY V1 - Waiting for JTAG"                 ║
// ║  6. (30-60s) Optional: Connect JTAG, show terminal with PING/PONG         ║
// ╚════════════════════════════════════════════════════════════════════════════╝
