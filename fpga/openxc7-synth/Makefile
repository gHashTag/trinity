FAMILY  = artix7
PART    = xc7a100tfgg676-1
PROJECT = trinity
TOP_MODULE = trinity_top
XDC     = trinity.xdc

# Paths for openXC7 tools (snap-based)
NEXTPNR_XILINX_DIR ?= /snap/openxc7/current/opt/nextpnr-xilinx
NEXTPNR_XILINX_PYTHON_DIR ?= $(NEXTPNR_XILINX_DIR)/python
PRJXRAY_DB_DIR ?= $(NEXTPNR_XILINX_DIR)/external/prjxray-db
CHIPDB ?= ./chipdb/

DBPART = $(shell echo $(PART) | sed -e 's/-[0-9]//g')

PYPY3 ?= pypy3

.PHONY: all clean

all: $(PROJECT).bit

$(PROJECT).json: $(PROJECT).v
	yosys -p "synth_xilinx -flatten -abc9 -arch xc7 -top $(TOP_MODULE); write_json $(PROJECT).json" $<

$(CHIPDB)/$(DBPART).bin:
	mkdir -p $(CHIPDB)
	$(PYPY3) $(NEXTPNR_XILINX_PYTHON_DIR)/bbaexport.py --device $(PART) --bba $(DBPART).bba
	bbasm -l $(DBPART).bba $(CHIPDB)/$(DBPART).bin
	rm -f $(DBPART).bba

$(PROJECT).fasm: $(PROJECT).json $(CHIPDB)/$(DBPART).bin $(XDC)
	nextpnr-xilinx --chipdb $(CHIPDB)/$(DBPART).bin --xdc $(XDC) --json $(PROJECT).json --fasm $@

$(PROJECT).frames: $(PROJECT).fasm
	fasm2frames --part $(PART) --db-root $(PRJXRAY_DB_DIR)/$(FAMILY) $< > $@

$(PROJECT).bit: $(PROJECT).frames
	xc7frames2bit --part_file $(PRJXRAY_DB_DIR)/$(FAMILY)/$(PART)/part.yaml --part_name $(PART) --frm_file $< --output_file $@

clean:
	rm -f *.bit *.frames *.fasm *.json
	rm -rf chipdb/
