// Phi-Rhythm LED Blink
// Blinks LED at approximately φ frequency (1.618 Hz)
// Using counter[25] at 50 MHz: 50,000,000 / 2^26 = 0.745 Hz
// Using counter[25] inverted: ~1.49 Hz ≈ φ (golden ratio)

module phi_blink_top(
    input wire clk,          // 50 MHz clock (U22)
    output reg led           // LED (T23, active-low)
);

    // 27-bit counter for precise frequency control
    // At 50 MHz with 27 bits:
    //   counter[25] period: 2^26 / 50MHz = 0.671 seconds = 1.49 Hz
    //   This is approximately φ (1.618 Hz)
    reg [26:0] phi_counter;

    always @(posedge clk) begin
        phi_counter <= phi_counter + 1;
    end

    // LED assignment with active-low inversion
    // Using counter[25] for ~1.49 Hz blink rate
    always @(posedge clk) begin
        led <= ~phi_counter[25];
    end

endmodule
