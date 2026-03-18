# Makefile for FPGA testbenches
# Supports: Icarus Verilog, Verilator, GTKWave

# Simulator selection
SIMULATOR ?= iverilog
VIEWER ?= gtkwave

# Source files
RTL_DIR = ..
VHDL_FILES =
VERILOG_FILES = $(wildcard $(RTL_DIR)/*.v)
TESTBENCH_FILES = $(wildcard tb_*.v)

# Output
SIM_DIR = sim
VCD_DIR = waves

# Colors
CYAN = \033[0;36m
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[1;33m
NC = \033[0m

.PHONY: all clean simulate help view

help:
	@echo "FPGA Testbench Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Run all testbenches"
	@echo "  simulate   - Same as all"
	@echo "  clean      - Remove generated files"
	@echo "  view <tb>  - View waveform for testbench (e.g., make view tb_temporal_heartbeat)"
	@echo "  help       - Show this message"
	@echo ""
	@echo "Variables:"
	@echo "  SIMULATOR  - iverilog (default) or verilator"
	@echo "  VIEWER     - gtkwave (default)"
	@echo ""
	@echo "Examples:"
	@echo "  make"
	@echo "  make view tb_temporal_heartbeat"
	@echo "  SIMULATOR=verilator make"

all: simulate

simulate: $(SIM_DIR) $(VCD_DIR)
	@echo "$(CYAN)Running testbenches...$(NC)"
	@for tb in $(TESTBENCH_FILES); do \
		tbname=$${tb%.v}; \
		echo "$(YELLOW)Compiling $$tbname...$(NC)"; \
		if [ "$(SIMULATOR)" = "iverilog" ]; then \
			iverilog -g2012 -o $(SIM_DIR)/$$tbname $$tb $(VERILOG_FILES) 2>&1; \
			if [ $$? -eq 0 ]; then \
				echo "$(GREEN)✓ Compiled$$ $(NC)"; \
				echo "$(CYAN)Simulating...$(NC)"; \
				cd $(SIM_DIR) && vvp $$tbname; \
				if [ $$? -eq 0 ]; then \
					echo "$(GREEN)✓ Passed$$ $(NC)"; \
				else \
					echo "$(RED)✗ Failed$$ $(NC)"; \
				fi; \
				cd ..; \
				if [ -f $(SIM_DIR)/$$tbname.vcd ]; then \
					mv $(SIM_DIR)/$$tbname.vcd $(VCD_DIR)/; \
				fi; \
			else \
				echo "$(RED)✗ Compilation failed$$ $(NC)"; \
			fi; \
		fi; \
		echo ""; \
	done
	@echo "$(CYAN)WAVEFORMS AVAILABLE IN: $(VCD_DIR)/$(NC)"

view:
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "$(RED)Error: Specify testbench name$(NC)"; \
		echo "Example: make view tb_temporal_heartbeat"; \
	else \
		vcd_file="$(VCD_DIR)/$(word 2,$(MAKECMDGOALS)).vcd"; \
		if [ -f $$vcd_file ]; then \
			echo "$(CYAN)Opening $$vcd_file...$(NC)"; \
			$(VIEWER) $$vcd_file & \
		else \
			echo "$(RED)Error: VCD file not found: $$vcd_file$(NC)"; \
			echo "Run 'make simulate' first."; \
		fi; \
	fi

$(SIM_DIR):
	mkdir -p $(SIM_DIR)

$(VCD_DIR):
	mkdir -p $(VCD_DIR)

clean:
	@echo "$(YELLOW)Cleaning generated files...$(NC)"
	rm -rf $(SIM_DIR) $(VCD_DIR)
	@echo "$(GREEN)✓ Cleaned$(NC)"

# Verilator support
verilator/%.mk: %.v $(VERILOG_FILES)
	@echo "$(YELLOW)Verilating $<...$(NC)"
	verilator --cc --exe $< $(VERILOG_FILES) -CFLAGS "-I$(shell pwd)" -Mdir $(@D)

# Individual test targets
tb_%: tb_%.v
	@echo "$(CYAN)Running $@...$(NC)"
	iverilog -g2012 -o $(SIM_DIR)/$@ $< $(VERILOG_FILES)
	cd $(SIM_DIR) && vvp $@
	@if [ -f $(SIM_DIR)/$@.vcd ]; then \
		mv $(SIM_DIR)/$@.cd $(VCD_DIR)/; \
	fi
