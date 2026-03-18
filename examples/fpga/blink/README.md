# LED Blink Example

Simplest FPGA example — a single blinking LED.

## What It Does

LED D6 (R23) blinks at approximately 1.5 Hz (about 2/3 second on, 2/3 second off).

## How It Works

1. **26-bit counter** counts clock cycles at 50 MHz
2. **Bit 25** toggles every 2^25 = 33,554,432 cycles
3. At 50 MHz, that's 0.671 seconds per toggle = 1.342 second period
4. **Active-low inversion** — the LED is ON when the output is 0

## Build & Flash

```bash
# From project root:
zig build tri -- fpga flash examples/fpga/blink/blink.vibee
```

## Expected Behavior

- LED D6 (PRIMARY, red LED at R23) blinks at ~1.5 Hz
- Approximately 2/3 second ON, 2/3 second OFF

## Hardware Notes

- **Pin R23** is the PRIMARY LED (D6) on the QMTECH board
- LED is **active-low**: 0 = ON, 1 = OFF
- Always invert your output signal!

## Code Explanation

```verilog
reg [25:0] counter = 26'h0;  // 26-bit counter (0 to 67,108,863)

always @(posedge clk) begin
    counter <= counter + 1'b1;  // Increment every clock cycle
end

assign led = ~counter[25];  // Use bit 25 (toggles every 33M cycles)
```

- `counter[25]` toggles every 2^25 = 33,554,432 clock cycles
- At 50 MHz: 33,554,432 / 50,000,000 = 0.671 seconds
- `~` inverts for active-low LED

## Modifying the Blink Rate

Change the counter bit to adjust blink rate:

| Bit | Period | Frequency | Blink Rate |
|-----|--------|-----------|------------|
| 20 | 21 ms | 48 Hz | Too fast to see |
| 22 | 84 ms | 12 Hz | Flicker |
| **24** | **336 ms** | **3 Hz** | Fast blink |
| **25** | **671 ms** | **1.5 Hz** | **Default** |
| 26 | 1.34 s | 0.75 Hz | Slow blink |

For example:
```verilog
assign led = ~counter[24];  // Faster blink (3 Hz)
assign led = ~counter[26];  // Slower blink (0.75 Hz)
```

## Troubleshooting

### LED stays OFF
- Check if JTAG programming completed successfully
- Verify pin R23 is correct (not T23!)
- Check `~` inversion in the code

### LED stays ON
- You forgot the `~` inversion
- LED is active-low, so 1 = OFF, 0 = ON

### LED blinks too fast/slow
- Adjust the counter bit used (see table above)
