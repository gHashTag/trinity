# FPGA RTL Modules

Reusable Verilog modules for Trinity FPGA development.

## Modules

| Module | Purpose | Status |
|--------|---------|--------|
| `uart_tx.v` | UART transmitter | ✅ Complete |
| `uart_rx.v` | UART receiver | ✅ Complete |
| `fpga_test_reporter.v` | Test result reporter | ✅ Complete |

## UART Communication

### Pinout (QMTECH XC7A100T)

Connect USB-UART adapter to FPGA GPIO pins:

| FPGA Pin | UART Signal | Description |
|----------|-------------|-------------|
| GPIO_0 | TX | FPGA → PC |
| GPIO_1 | RX | PC → FPGA |
| GND | GND | Common ground |

### Baud Rate

Default: 115200 baud (configurable via parameter)

### Protocol

Commands (sent TO FPGA):
- `PING\n` - Request status
- `TEST\n` - Run test suite
- `RESET\n` - Soft reset

Responses (sent FROM FPGA):
- `PASS:test_name\n` - Test passed
- `FAIL:test_name:reason\n` - Test failed
- `STATUS:msg\n` - Status message

## Usage Example

```verilog
// In your top module
uart_tx #(
    .CLK_FREQ(50_000_000),
    .BAUD(115200)
) uart (
    .clk(clk),
    .rst(rst),
    .data(tx_data),
    .start(tx_start),
    .uart_tx(uart_tx_pin),
    .busy(tx_busy)
);
```

## Testing

```bash
# Connect USB-UART adapter
screen /dev/tty.usbserial-*. 115200

# Send commands
echo "TEST" > /dev/tty.usbserial-*

# View responses
cat /dev/tty.usbserial-*
```
