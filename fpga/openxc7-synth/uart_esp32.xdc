# =============================================================================
# UART ESP32 Interface - QMTECH Artix-7 XC7A100T-1FGG676C
# =============================================================================
#
# ESP32 Connection:
#   ESP32 IO4 (TX)  -> FPGA IO_0_25 (Pin L20) -> uart_rx
#   ESP32 IO5 (RX)  <- FPGA IO_0_26 (Pin K20) <- uart_tx
#   ESP32 GND       -> FPGA GND (CRITICAL!)
#
# ESP32 DIYTZT Board Pinout:
#   GPIO4  = TX (send to FPGA)
#   GPIO5  = RX (receive from FPGA)
#   GPIO14 = CLK (optional SPI)
#   GPIO12 = MISO (optional SPI)
#   GPIO13 = MOSI (optional SPI)
#   GPIO15 = CS  (optional SPI)
#
# =============================================================================

# Clock (50 MHz oscillator)
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Reset (active high, connect to 3.3V for normal operation)
set_property LOC V22 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

# UART RX (receive from ESP32 TX - GPIO4)
set_property LOC L20 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

# UART TX (send to ESP32 RX - GPIO5)
set_property LOC K20 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# Status LED (onboard LED D6)
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# Debug outputs (optional, for logic analyzer)
set_property LOC M22 [get_ports debug_state[0]]
set_property IOSTANDARD LVCMOS33 [get_ports debug_state[0]]

set_property LOC N21 [get_ports debug_state[1]]
set_property IOSTANDARD LVCMOS33 [get_ports debug_state[1]]

set_property LOC N20 [get_ports debug_state[2]]
set_property IOSTANDARD LVCMOS33 [get_ports debug_state[2]]

set_property LOC P22 [get_ports debug_state[3]]
set_property IOSTANDARD LVCMOS33 [get_ports debug_state[3]]

# =============================================================================
# Optional: SPI Interface (for future expansion)
# =============================================================================
# ESP32 GPIO14 (CLK) -> FPGA IO_0_27 (Pin J21)
# ESP32 GPIO12 (MISO) <- FPGA IO_0_28 (Pin H21)
# ESP32 GPIO13 (MOSI) -> FPGA IO_0_29 (Pin G22)
# ESP32 GPIO15 (CS) -> FPGA IO_0_30 (Pin F22)
# =============================================================================
