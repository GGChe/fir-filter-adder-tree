TOPLEVEL_LANG = verilog
SIM = icarus

TOPLEVEL = fir
COCOTB_TEST_MODULES = test_fir

SRC_DIR = $(PWD)/../../src

VERILOG_SOURCES = \
  $(SRC_DIR)/fir.v

$(VERILOG_SOURCES): ;

coeffs:
	cp $(SRC_DIR)/fir_coeffs_q15.hex .

sim: coeffs

include $(shell cocotb-config --makefiles)/Makefile.sim
