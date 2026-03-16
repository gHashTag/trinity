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

## TMU (Ternary MatMul Unit) — K-parallel dot product
sim-tmu:
	iverilog -o tmu_test tmu.v tmu_tb.v && ./tmu_test

synth-tmu:
	yosys -p "read_verilog tmu.v; synth_xilinx -flatten -abc9 -arch xc7 -top tmu; stat"

sim-tmu-full:
	iverilog -DNOWAVE -o hslm_full_test tmu.v tmu_top.v ternary_activation.v ternary_rmsnorm.v \
	  trinity_block.v embedding_lookup.v argmax_unit.v \
	  hslm_full_top.v hslm_full_top_tb.v && ./hslm_full_test

sim-tmu-full-wave:
	iverilog -o hslm_full_test tmu.v tmu_top.v ternary_activation.v ternary_rmsnorm.v \
	  trinity_block.v embedding_lookup.v argmax_unit.v \
	  hslm_full_top.v hslm_full_top_tb.v && ./hslm_full_test

synth-tmu-full:
	yosys -p "read_verilog tmu.v tmu_top.v ternary_activation.v ternary_rmsnorm.v \
	  trinity_block.v embedding_lookup.v argmax_unit.v \
	  hslm_full_top.v; \
	  synth_xilinx -flatten -abc9 -arch xc7 -top hslm_full_top; stat" \
	  2>&1 | tee synth_reports/hslm_tmu_full.log

## HSLM Full — Yosys synth only (wide BRAM, K=32 + BSCANE2 bridge)
HSLM_SRCS = tmu.v tmu_top.v ternary_activation.v ternary_rmsnorm.v \
            trinity_block.v embedding_lookup.v argmax_unit.v hslm_full_top.v

synth-hslm:
	@mkdir -p synth_reports
	yosys -p "read_verilog $(HSLM_SRCS); \
	  synth_xilinx -flatten -abc9 -arch xc7 -top hslm_full_top; stat" \
	  2>&1 | tee synth_reports/hslm_wide_bram.log

## HSLM Full — complete bitstream pipeline (requires openXC7 toolchain)
hslm_full_top.json: $(HSLM_SRCS)
	yosys -p "read_verilog $(HSLM_SRCS); \
	  synth_xilinx -flatten -abc9 -arch xc7 -top hslm_full_top; \
	  write_json $@"

hslm_full_top.fasm: hslm_full_top.json $(CHIPDB)/$(DBPART).bin hslm_full_top.xdc
	nextpnr-xilinx --chipdb $(CHIPDB)/$(DBPART).bin --xdc hslm_full_top.xdc \
	  --json hslm_full_top.json --fasm $@

hslm_full_top.frames: hslm_full_top.fasm
	fasm2frames --part $(PART) --db-root $(PRJXRAY_DB_DIR)/$(FAMILY) $< > $@

hslm_full_top.bit: hslm_full_top.frames
	xc7frames2bit --part_file $(PRJXRAY_DB_DIR)/$(FAMILY)/$(PART)/part.yaml \
	  --part_name $(PART) --frm_file $< --output_file $@

## Pack weights: 32 bank .mem → 1 wide .mem (requires weight_pack_wide tool)
pack-weights:
	@echo "Packing lm_head..."
	../tools/weight_pack_wide lm_head 32 1024
	@for prefix in tmu_w_b1_up tmu_w_b1_down tmu_w_b2_up tmu_w_b2_down tmu_w_b3_up tmu_w_b3_down; do \
	  echo "Packing $$prefix..."; \
	  ../tools/weight_pack_wide $$prefix 32 5832; \
	done

clean:
	rm -f *.bit *.frames *.fasm *.json tmu_test *.vcd
	rm -rf chipdb/
