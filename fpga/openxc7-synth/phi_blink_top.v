// Fast LED Blink
// Blinks LED at approximately 24 Hz (fast visible blink)
// Using counter[20] at 50 MHz: 50,000,000 / 2^21 = 23.8 Hz

module phi_blink_top(
    input wire clk,          // 50 MHz clock (U22)
    output reg led           // LED (T23, active-low)
);

    // 21-bit counter for fast blink
    // At 50 MHz with 21 bits:
    //   counter[20] period: 2^21 / 50MHz = 0.042 seconds = 23.8 Hz
    reg [20:0] fast_counter;

    always @(posedge clk) begin
        fast_counter <= fast_counter + 1;
    end

    // LED assignment with active-low inversion
    // Using counter[20] for ~24 Hz blink rate (fast visible)
    always @(posedge clk) begin
        led <= ~fast_counter[20];
    end

endmodule
