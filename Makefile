# ============================================================
# Cocotb configuration
# ============================================================

export COCOTB_WAVES        = 1
export COCOTB_WAVE_FORMAT = fst

TOPLEVEL_LANG       ?= verilog
TOPLEVEL            ?= fir_tkeo_chain
COCOTB_TEST_MODULES ?= test_fir_tkeo
SIM                 ?= verilator


VERILOG_SOURCES = fir_tkeo_chain.v
TB_RTL = tb_fir_tkeo_chain.v


EXTRA_ARGS += --trace-fst --trace-structs
WAVE_FST   := sim_build/dump.fst


GTK_LAYOUT := layout.sav
TCL_SCRIPT := tcl_scripts/signals.tcl

IVERILOG_FLAGS := -g2005-sv
RTL_SIM_OUT    := sim_rtl.out
RTL_WAVE       := wave.vcd

TKEO_RTL_SOURCES := fir_tkeo_chain.v
TKEO_TB          := tb_tkeo.v
TKEO_SIM_OUT     := sim_tkeo.out
TKEO_WAVE        := wave_tkeo.vcd


.PHONY: test rtl rtl_tkeo clean

test:
	$(MAKE) SIM=$(SIM) sim
	gtkwave -a $(TCL_SCRIPT) $(WAVE_FST) $(GTK_LAYOUT)

rtl_chain:
	iverilog $(IVERILOG_FLAGS) \
		-o $(RTL_SIM_OUT) \
		$(VERILOG_SOURCES) $(TB_RTL)
	vvp $(RTL_SIM_OUT)
	gtkwave -a $(TCL_SCRIPT) $(RTL_WAVE) $(GTK_LAYOUT)

rtl_tkeo:
	iverilog $(IVERILOG_FLAGS) \
		-o $(TKEO_SIM_OUT) \
		$(TKEO_RTL_SOURCES) $(TKEO_TB)
	vvp $(TKEO_SIM_OUT)
	gtkwave $(TKEO_WAVE)

clean::
	rm -rf sim_build
	rm -f results.xml
	rm -rf __pycache__ .pytest_cache
	rm -f *.csv *.html *.vcd *.fst *.wlf transcript
	rm -f $(RTL_SIM_OUT) $(TKEO_SIM_OUT)


include $(shell cocotb-config --makefiles)/Makefile.sim
