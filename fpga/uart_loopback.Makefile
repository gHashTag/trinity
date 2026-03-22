# Makefile for UART Loopback Test
# QMTech XC7A100T FGG676 Core Board

# Tools
OPENOCD ?= openocd
YOSYS ?= yosys
NEXTPNR ?= nextpnr-fpga-xc7
TAS ?= fasm2frames

# Project name
PROJECT ?= uart_loopback

# Top module
TOP ?= uart_loopback

# Synthesis
all: $(YOSYS) -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top $(TOP)" \
           -o $(TOP).json write_json uart_loopback.json

# Place and Route
place: $(YOSYS) -p "nextpnr-xc7 -xdc uart_loopback_core.xdc" \
           -place_and_route $(TOP).ncd

# Generate bitstream
bitstream: $(YOSYS) -p "fasm2frames + xc7frames2bit" \
           -o $(TOP).bit $(TOP).ncd

# Flash using JTAG
flash: $(OPENOCD) -c "program -f uart_loopback.bit"

# Clean
clean:
	rm -rf build/ *.ncd *.json *.bit

.PHONY: .NOTINTERMEDIATE
