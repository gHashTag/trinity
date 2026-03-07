# Multi-LED Patterns Example

Demonstrates three different LED patterns selectable via button.

## What It Does

The 8 LEDs display different patterns based on button presses:

| Pattern | Description | Visual |
|---------|-------------|--------|
| 0 (default) | Chase | LED chases left to right |
| 1 | Counter | Binary counter (0-255) |
| 2 | Blink | All LEDs blink together |

Press the button (BTN_N) to cycle through patterns.

## Build & Flash

```bash
# From project root:
zig build tri -- fpga flash examples/fpga/multi_led/multi_led.vibee
```

## Expected Behavior

1. **Default (Pattern 0)**: LEDs "chase" from left to right
   - D6 → D5 → D4 → D3 → D2 → D1 → D0 → D7 → repeat

2. **Press button once** → Pattern 1: Binary counter
   - Counts 0 → 255 repeatedly

3. **Press button again** → Pattern 2: All blink
   - All LEDs turn on/off together

4. **Press button again** → Back to Pattern 0

## How It Works

### Pattern Selector

```verilog
reg [1:0] pattern = 2'b00;  // 0=chase, 1=counter, 2=blink

// Button press increments pattern
wire btn_press = /* synchronized and debounced */;
always @(posedge clk) begin
    if (btn_press)
        pattern <= pattern + 1'b1;
end
```

### Pattern 0: Chase

```verilog
case (counter[23:21])  // 3-bit position (0-7)
    3'b000: led_pattern = 8'b00000001;
    3'b001: led_pattern = 8'b00000010;
    // ... etc
```

Uses 3 bits of counter to select which LED is ON.

### Pattern 1: Counter

```verilog
led_pattern <= counter[25:18];  // Upper 8 bits
```

Simply displays bits of the counter.

### Pattern 2: Blink

```verilog
led_pattern = {8{counter[25]}};  // All same bit
```

All LEDs show the same bit (blink together).

## Button Handling

Buttons require synchronization and debouncing:

```verilog
// 3-stage synchronizer (metastability protection)
reg btn_sync_0, btn_sync_1, btn_sync_2;
always @(posedge clk) begin
    btn_sync_0 <= btn;
    btn_sync_1 <= btn_sync_0;
    btn_sync_2 <= btn_sync_1;
end

// Detect falling edge (button press, active-low)
wire btn_press = (btn_sync_2 == 1'b0) && (btn_sync_1 == 1'b1);
```

## Hardware Notes

- **Button**: BTN_N (North button) at pin L22
- Button is **active-low** with pull-up resistor
- **LEDs**: All active-low (inverted in output)

## Troubleshooting

### Button doesn't change pattern
- Verify button pin (L22) is correct
- Check button synchronization logic
- Try pressing longer (debounce may be too aggressive)

### LED behavior doesn't match pattern
- Check `assign led = ~led_pattern;` inversion
- Verify case statement covers all patterns

### Pattern changes randomly
- Button debouncing may need adjustment
- Add more synchronization stages if needed

## Customization

### Change chase speed

Adjust which counter bits are used:
```verilog
// Faster chase (use lower bits)
case (counter[20:18])

// Slower chase (use higher bits)
case (counter[26:24])
```

### Add more patterns

Extend the pattern selector:
```verilog
reg [2:0] pattern;  // 0-6 instead of 0-2

case (pattern)
    3'b011: // New pattern 3
    3'b100: // New pattern 4
    // etc...
endcase
```
