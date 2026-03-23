// VERY SLOW LED Blink — для проверки что прошивка работает
// Blinks LED at ~0.37 Hz (в 2× медленнее чем старая 0.74 Hz)
// Using counter[26] at 50 MHz: 50,000,000 / 2^27 = 0.37 Hz

module blink_test_top(
    input wire clk,          // 50 MHz clock (U22)
    output reg led           // LED (T23, active-low)
);

    // 27-bit counter
    reg [26:0] slow_counter;

    always @(posedge clk) begin
        slow_counter <= slow_counter + 1;
    end

    // LED assignment with active-low inversion
    // Using counter[26] for ~0.37 Hz blink rate (ОЧЕНЬ МЕДЛЕННО)
    always @(posedge clk) begin
        led <= ~slow_counter[26];
    end

endmodule
