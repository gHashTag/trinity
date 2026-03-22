# UART Echo Synthesis Makefile
# Target: QMTech XC7A100T-1FGG676C
# Tools: Yosys, nextpnr-xilinx, fasm2frames, xc7patch

YOSYS ?= yosys
TOP_MODULE ?= uart_echo_top
DEVICE ?= xc7a100t-fgg484-1

# Source files
RTL_SOURCES = uart_echo_top.v
XDC_CONSTRAINTS = uart_echo_top.xdc

# Output files
BLIF_OUTPUT = $(TOP_MODULE).blif
JSON_OUTPUT = $(TOP_MODULE).json
FASM_OUTPUT = $(TOP_MODULE).fasm
FRAMES_OUTPUT = $(TOP_MODULE).frames
BITSTREAM_OUTPUT = $(TOP_MODULE).bit

# Synthesis
synthesis: $(BLIF_OUTPUT)

$(BLIF_OUTPUT): $(RTL_SOURCES)
	@echo "[1/4] Running Yosys synthesis..."
	$(YOSYS) -p 'read_verilog $(RTL_SOURCES); synth_xilinx -family xc7 -top $(TOP_MODULE) -blif $(BLIF_OUTPUT)'
	@echo "✅ Yosys complete: $(BLIF_OUTPUT)"

# Place and route (requires nextpnr-xilinx)
place_route: $(FASM_OUTPUT)

$(FASM_OUTPUT): $(BLIF_OUTPUT) $(XDC_CONSTRAINTS)
	@echo "[2/4] Running nextpnr-xilinx..."
	@echo "   ERROR: nextpnr-xilinx not installed!"
	@echo "   Install: pip install nextpnr-xilinx"
	@exit 1

# Generate bitstream (requires fasm2frames + xc7patch)
bitstream: $(BITSTREAM_OUTPUT)

$(BITSTREAM_OUTPUT): $(FASM_OUTPUT)
	@echo "[3/4] Generating bitstream..."
	@echo "   ERROR: fasm2frames or xc7patch not installed!"
	@echo "   This requires SymbiFlow/prjxray toolchain"
	@exit 1

# Clean
clean:
	@rm -f *.blif *.json *.fasm *.frames *.bit
	@rm -f *.log
	@echo "✅ Cleaned"

# Help
help:
	@echo "UART Echo Synthesis"
	@echo ""
	@echo "Usage:"
	@echo "  make synthesis          - Run Yosys (requires yosys)"
	@echo "  make place_route       - Place & route (requires nextpnr-xilinx)"
	@echo "  make bitstream        - Generate .bit (requires fasm2frames + xc7patch)"
	@echo "  make clean             - Clean outputs"
	@echo ""
	@echo "Requirements:"
	@echo "  - yosys (synthesis)"
	@echo "  - nextpnr-xilinx (placement & routing)"
	@echo "  - fasm2frames (FASM to frames)"
	@echo "  - xc7patch (frames to bitstream)"
	@echo ""
	@echo "Install all: pip install nextpnr-xilinx fasm2frames xc7patch"

.PHONY: synthesis place_route bitstream clean help
