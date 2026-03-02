`default_nettype none

// TRINITY FPGA — QMTECH XC7A100T Core Board LED Blink
// Clock: 50 MHz (M22) | LED: J19 (active-low)
// phi^2 + 1/phi^2 = 3 = TRINITY

module trinity_top (
    input  wire clk,
    output wire led
);

    reg [25:0] counter = 26'd0;

    // LED heartbeat: blink ~1.5 Hz (50MHz / 2^25 ~ 1.49 Hz)
    // Active-low LED: invert so LED visibly blinks
    assign led = ~counter[24];

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

endmodule
