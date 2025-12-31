# ============================================================
# Cocotb configuration
# ============================================================

export CXX = g++
export CC = gcc
export COCOTB_WAVES        = 1
export COCOTB_WAVE_FORMAT = fst

SIM ?= verilator
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES = $(PWD)/src/fir.v
TOPLEVEL = fir_filter
MODULE = test_fir

# Enable FST tracing for Verilator
EXTRA_ARGS += --trace --trace-fst --trace-structs
# Pass absolute path for coefficients to avoid CWD issues
EXTRA_ARGS += -GCOEFF_FILE='\"$(PWD)/src/fir_coeffs_q15.hex\"'

export PYTHONPATH := $(PWD)/tb/cocotb:$(PYTHONPATH)
# export EXTRA_ARGS += -I$(PWD)/src --trace --trace-fst --trace-structs --compiler gcc
export PLUSARGS += +trace

.PHONY: test-cocotb test-verilog view-cocotb view-verilog clean

# Run Cocotb testbench
test-cocotb:
	cd tb/cocotb && poetry run $(MAKE) SIM=$(SIM)


# Run Verilog testbench (Icarus Verilog)
test-verilog:
	iverilog -g2005-sv -o sim_rtl.out $(VERILOG_SOURCES) $(PWD)/tb/verilog/tb_fir.v
	vvp sim_rtl.out

# View Cocotb waveforms
view-cocotb:
	gtkwave --script tcl_scripts/signals.tcl tb/cocotb/dump.fst

# View Verilog testbench waveforms
view-verilog: test-verilog
	gtkwave -f wave.gtkw

# Legacy targets
test: test-cocotb view-cocotb
rtl: test-verilog view-verilog

clean::
	rm -rf sim_build __pycache__ .pytest_cache
	rm -f results.xml *.csv *.html *.vcd *.fst *.wlf transcript sim_rtl.out
	cd tb/cocotb && rm -rf sim_build __pycache__ results.xml *.csv *.html *.fst
