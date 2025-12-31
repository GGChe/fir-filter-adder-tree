SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Force G++ for Verilator in this environment
CXX = g++
LINK = g++

SRC_DIR = $(PWD)/../../src
VERILOG_SOURCES += $(SRC_DIR)/fir.v

# Pass absolute path to coefficients and enable tracing
EXTRA_ARGS += --trace --trace-fst --trace-structs -GCOEFF_FILE='"$(SRC_DIR)/fir_coeffs_q15.hex"'

TOPLEVEL = fir_filter
MODULE = test_fir

include $(shell cocotb-config --makefiles)/Makefile.sim