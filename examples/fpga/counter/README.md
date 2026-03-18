# 8-Bit Binary Counter Example

Displays a binary counter on the 8-LED bar.

## What It Does

The 8 LEDs display a binary counting sequence:
- 00000000 (all LEDs ON due to active-low)
- 00000001
- 00000010
- 00000011
- ...
- 11111111 (all LEDs OFF due to active-low)
- Then wraps back to 00000000

## LED Layout (Left to Right)

```
┌────┬────┬────┬────┬────┬────┬────┬────┐
│ D6 │ D5 │ D4 │ D3 │ D2 │ D1 │ D0 │ D7 │
│led0│led1│led2│led3│led4│led5│led6│led7│
│ MSB│    │    │    │    │    │    │ LSB │
└────┴────┴────┴────┴────┴────┴────┴────┘
```

Due to the board layout, LEDs are wired in a non-linear order. The spec handles this mapping.

## Build & Flash

```bash
# From project root:
zig build tri -- fpga flash examples/fpga/counter/counter.vibee
```

## Expected Behavior

- LEDs cycle through all 256 binary values
- Updates approximately 4 times per second
- Each count lasts about 0.25 seconds

## How It Works

```verilog
reg [26:0] counter = 27'h0;      // Main timing counter
reg [23:0] slow_counter = 24'h0;  // Visible counter (8 bits used)

always @(posedge clk) begin
    counter <= counter + 1'b1;
    if (counter[23] == 1'b1) begin
        slow_counter <= slow_counter + 1'b1;
    end
end

assign led = ~slow_counter[7:0];  // Invert for active-low
```

1. **Main counter** runs at 50 MHz
2. **Bit 23** is used as an enable (toggles every ~0.17 seconds)
3. **slow_counter** increments when enabled
4. **Lower 8 bits** of slow_counter go to LEDs
5. **Active-low inversion** via `~`

## Binary Counting Reference

| Binary | Decimal | LEDs (ON = 0) |
|--------|---------|----------------|
| 00000000 | 0 | ████████ (all ON) |
| 00000001 | 1 | ███████○ |
| 00000010 | 2 | ███████○ |
| 00001111 | 15 | █████○○○○ |
| 11111111 | 255 | ○○○○○○○○ (all OFF) |

## Hardware Notes

- All LEDs are **active-low**: 0 = ON, 1 = OFF
- Bit 0 = LSB (D7) = rightmost LED
- Bit 7 = MSB (D6) = leftmost LED

## Troubleshooting

### LEDs not changing
- Verify JTAG programming completed
- Check all 8 pins in constraints

### Wrong LED order
- The pin order in the spec maps logical bits to physical LEDs
- led[0] is MSB (D6), led[7] is LSB (D7)

### Counting too fast/slow
- Adjust which bit of `counter` is used for the enable
- Higher bit = slower, lower bit = faster
