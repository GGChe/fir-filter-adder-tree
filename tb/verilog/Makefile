SIM = iverilog
TOP = fir_tkeo_chain

SRCS = \
  ../../src/fir.v \
  tb_fir.v

all: coeffs
	iverilog -g2005-sv -o sim.out $(SRCS)
	vvp sim.out

coeffs:
	cp ../../src/fir_coeffs_q15.hex .

wave:
	gtkwave wave.vcd

clean:
	rm -f sim.out wave.vcd
