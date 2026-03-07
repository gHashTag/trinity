# QMTECH Artix-7 XC7A100T FGG676 Pinout Reference

## Board Specifications

| Spec | Value |
|------|-------|
| FPGA | Artix-7 XC7A100T-1FGG676C |
| Package | FGG676 (676-ball BGA) |
| Speed Grade | -1 (industrial, -40°C to +100°C) |
| Logic Cells | 101,440 |
| Slice Registers | 126,800 |
| Slice LUTs | 63,400 |
| Block RAM | 4.9 Mb (270 36Kb blocks) |
| DSP Slices | 240 |

---

## Clock Resources

| Signal | Pin | Bank | Type | Frequency | Notes |
|--------|-----|------|------|-----------|-------|
| **CLK0** | **U22** | 13 | DIFF_P | 50 MHz | On-board oscillator ⭐ |
| CLK0_N | U21 | 13 | DIFF_N | 50 MHz | Differential pair (unused) |

**⚠️ CRITICAL:** Use U22 for single-ended 50 MHz clock input.

---

## LEDs (Active-Low)

| LED | Color | Pin | Bank | Notes |
|-----|-------|-----|------|-------|
| **D6** | Red | **R23** | 13 | Primary LED ⭐ |
| D5 | Red | T23 | 13 | Secondary LED |
| D4 | Green | P24 | 13 | |
| D3 | Green | R24 | 13 | |
| D2 | Yellow | N22 | 13 | |
| D1 | Yellow | P22 | 13 | |
| D0 | Blue | M24 | 13 | |
| D7 | Blue | N24 | 13 | |

**⚠️ ALL LEDs are ACTIVE-LOW:**
- `led = 0` → LED **ON**
- `led = 1` → LED **OFF**

Always invert your logic: `assign led_out = ~led_signal;`

---

## Buttons

| Button | Pin | Bank | Type | Notes |
|--------|-----|------|------|-------|
| BTN_RESET | K22 | 13 | Active-low | System reset |
| BTN_N | L22 | 13 | Active-low | North button |
| BTN_S | L21 | 13 | Active-low | South button |
| BTN_E | K21 | 13 | Active-low | East button |
| BTN_W | J22 | 13 | Active-low | West button |
| BTN_C | J21 | 13 | Active-low | Center button |

**All buttons have 4.7K pull-up resistors.**

---

## DIP Switches

| Switch | Pins | Bank | Notes |
|--------|-------|------|-------|
| SW0 | M22, M21 | 13 | DIP switch 0 |
| SW1 | L20, L19 | 13 | DIP switch 1 |
| SW2 | K20, K19 | 13 | DIP switch 2 |
| SW3 | J20, J19 | 13 | DIP switch 3 |
| SW4 | H20, H19 | 13 | DIP switch 4 |
| SW5 | H18, G20 | 13 | DIP switch 5 |
| SW6 | G19, F20 | 13 | DIP switch 6 |
| SW7 | F19, E20 | 13 | DIP switch 7 |

---

## UART (FTDI)

| Signal | Pin | Bank | Notes |
|--------|-----|------|-------|
| UART_TX | E21 | 16 | FTDI transmit |
| UART_RX | F21 | 16 | FTDI receive |
| UART_RTS | D20 | 16 | RTS (optional) |
| UART_CTS | G20 | 16 | CTS (optional) |

**Connected to FTDI USB chip (same as JTAG).**

---

## VGA (Optional)

| Signal | Pin | Bank | Notes |
|--------|-----|------|-------|
| VGA_RED[0] | H17 | 15 | Red channel bit 0 |
| VGA_RED[1] | K17 | 15 | Red channel bit 1 |
| VGA_RED[2] | J17 | 15 | Red channel bit 2 |
| VGA_RED[3] | H16 | 15 | Red channel bit 3 |
| VGA_GRN[0] | K16 | 15 | Green channel bit 0 |
| VGA_GRN[1] | J16 | 15 | Green channel bit 1 |
| VGA_GRN[2] | G17 | 15 | Green channel bit 2 |
| VGA_GRN[3] | H15 | 15 | Green channel bit 3 |
| VGA_BLU[0] | G16 | 15 | Blue channel bit 0 |
| VGA_BLU[1] | J15 | 15 | Blue channel bit 1 |
| VGA_BLU[2] | G15 | 15 | Blue channel bit 2 |
| VGA_BLU[3] | F15 | 15 | Blue channel bit 3 |
| VGA_HSYNC | F16 | 15 | Horizontal sync |
| VGA_VSYNC | G14 | 15 | Vertical sync |

---

## SD Card (SPI)

| Signal | Pin | Bank | Notes |
|--------|-----|------|-------|
| SD_CLK | E18 | 16 | SPI clock |
| SD_CMD | F18 | 16 | SPI command (MOSI) |
| SD_DAT0 | G18 | 16 | SPI data (MISO) |
| SD_DAT3 | D18 | 16 | Card detect |
| SD_CD | E19 | 16 | Card detect (optional) |

---

## Ethernet (RGMII)

| Signal | Pin | Bank | Notes |
|--------|-----|------|-------|
| ETH_TXCLK | C16 | 15 | Transmit clock |
| ETH_TXCTL | D15 | 15 | Transmit control |
| ETH_TXD[0] | E14 | 15 | Transmit data 0 |
| ETH_TXD[1] | E13 | 15 | Transmit data 1 |
| ETH_TXD[2] | F14 | 15 | Transmit data 2 |
| ETH_TXD[3] | F13 | 15 | Transmit data 3 |
| ETH_RXCLK | G13 | 15 | Receive clock |
| ETH_RXCTL | H14 | 15 | Receive control |
| ETH_RXD[0] | H13 | 15 | Receive data 0 |
| ETH_RXD[1] | J14 | 15 | Receive data 1 |
| ETH_RXD[2] | G12 | 15 | Receive data 2 |
| ETH_RXD[3] | H12 | 15 | Receive data 3 |
| ETH_MDC | K14 | 15 | Management clock |
| ETH_MDIO | K13 | 15 | Management data |
| ETH_RESET_N | L13 | 15 | Reset (active-low) |
| ETH_INT_N | L14 | 15 | Interrupt (active-low) |
| ETH_CRS | L15 | 15 | Carrier sense |
| ETH_COL | K15 | 15 | Collision detect |

---

## DDR3 (MT41J128M16HA)

| Signal | Pin | Bank | Notes |
|--------|-----|------|-------|
| DDR_A[0-14] | Various | 35 | Address |
| DDR_BA[0-2] | Various | 35 | Bank address |
| DDR_CAS_N | E10 | 35 | Column address strobe |
| DDR_CKE | E8 | 35 | Clock enable |
| DDR_CLK_N | E6 | 35 | Differential clock N |
| DDR_CLK_P | E7 | 35 | Differential clock P |
| DDR_CS_N | D10 | 35 | Chip select |
| DDR_DM[0-1] | F7, D8 | 35 | Data mask |
| DDR_DQ[0-15] | Various | 35 | Data |
| DDR_DQS_N[0-1] | G6, F8 | 35 | Data strobe N |
| DDR_DQS_P[0-1] | G7, F9 | 35 | Data strobe P |
| DDR_ODT | F5 | 35 | On-die termination |
| DDR_RAS_N | E9 | 35 | Row address strobe |
| DDR_RESET_N | G8 | 35 | Reset |
| DDR_WE_N | F10 | 35 | Write enable |
| DDR_VRN | Various | 35 | Reference N |
| DDR_VRP | Various | 35 | Reference P |

---

## USB (ULPI)

| Signal | Pin | Bank | Notes |
|--------|-----|------|-------|
| USB_CLK | N18 | 16 | ULPI clock |
| USB_STP | P18 | 16 | ULPI stop |
| USB_DIR | N17 | 16 | ULPI direction |
| USB NXT | M17 | 16 | ULPI next |
| USB_DATA[0-7] | Various | 16 | ULPI data |

---

## Arduino Headers (Optional)

### Header J1 (Arduino GPIO)

| Arduino | Pin | Bank | Notes |
|---------|-----|------|-------|
| D0 | R18 | 13 | GPIO |
| D1 | R17 | 13 | GPIO |
| D2 | N19 | 13 | GPIO |
| D3 | M19 | 13 | GPIO |
| D4 | P19 | 13 | GPIO |
| D5 | P17 | 13 | GPIO |
| D6 | N18 | 13 | GPIO |
| D7 | M18 | 13 | GPIO |
| D8 | L17 | 13 | GPIO |
| D9 | L18 | 13 | GPIO |
| D10 | L16 | 13 | GPIO |
| D11 | K18 | 13 | GPIO |
| D12 | K19 | 13 | GPIO |
| D13 | J18 | 13 | GPIO |

### Header J2 (Arduino SPI + I2C)

| Arduino | Pin | Bank | Notes |
|---------|-----|------|-------|
| SDA | H18 | 16 | I2C data |
| SCL | H19 | 16 | I2C clock |
| SCK | G19 | 16 | SPI clock |
| MISO | F17 | 16 | SPI MISO |
| MOSI | G17 | 16 | SPI MOSI |
| CS | F18 | 16 | SPI chip select |

---

## Power Rails

| Rail | Voltage | Current |
|------|---------|---------|
| VCCINT | 1.0V | Core logic |
| VCCAUX | 1.8V | Auxiliary |
| VCCBRAM | 1.0V | Block RAM |
| VCCADC | 1.8V | ADC |
| I/O Banks 13, 15, 16 | 3.3V | General purpose |
| I/O Bank 35 | 1.5V | DDR3 |

---

## Common Constraint Examples

### LED Output (Active-Low)

```yaml
constraints:
  - port: led
    pin: R23
    iostandard: LVCMOS33
```

Verilog:
```verilog
assign led = ~led_signal;  // Invert for active-low
```

### Button Input (Active-Low)

```yaml
constraints:
  - port: btn
    pin: K22
    iostandard: LVCMOS33
```

Verilog:
```verilog
// Synchronize button input
reg btn_sync_0, btn_sync_1;
always @(posedge clk) begin
    btn_sync_0 <= btn;
    btn_sync_1 <= btn_sync_0;
end
```

### UART (3.3V)

```yaml
constraints:
  - port: uart_tx
    pin: E21
    iostandard: LVCMOS33
  - port: uart_rx
    pin: F21
    iostandard: LVCMOS33
```

---

## φ² + 1/φ² = 3 = TRINITY

For full pinout spreadsheet, see QMTECH XC7A100T documentation.
