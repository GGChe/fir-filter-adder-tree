# FIR Filter with Adder Tree Optimization

This repository contains the RTL implementation and verification environment for an optimized FIR filter architecture, targeting low-power and efficient VLSI designs.
The project focuses on optimizing a classic FIR filter using techniques such as:

- Adder-tree based accumulation
- Pipelining and architectural restructuring
- Clock-gating and area-aware design decisions

The design is written in Verilog and is ready to be:

- Simulated with Icarus Verilog
- Visualized with GTKWave
- Synthesized using OpenROAD / Nangate libraries

## Repository Structure

```
fir-filter-adder-tree/
├── LICENSE
├── Makefile
├── README.md
├── src/
│   ├── fir.v                  # FIR (optimized architecture)
│   ├── tb_fir.v    # Testbench
│   ├── filter_design.py       # FIR coefficient generation (Python)
│   ├── synthesis.tcl          # OpenROAD synthesis script
│   ├── constrain.sdc          # Timing constraints
│   ├── nangate_mvt.odb        # Standard-cell library
│   └── setup.md               # Synthesis-specific notes
└── test_files/
    ├── lfp/                   # Real neural signal samples
    └── synthetic_noise/       # Synthetic test vectors

```
## Dependencies
Required tools (simulation)

Make sure the following tools are installed:
- Icarus Verilog (RTL simulation)
- GTKWave (waveform visualization)
- Make
- Python 3 (for FIR coefficient generation)

## Installation (Ubuntu / Debian)

```
sudo apt update
sudo apt install -y \
    iverilog \
    gtkwave \
    make \
    python3 \
    python3-numpy \
    python3-scipy
pip install cocotb numpy scipy plotly
sudo apt install iverilog gtkwave
sudo apt install verilator

```

Verify installation:

```
iverilog -V
gtkwave --version
python3 --version
```

## FIR Coefficient Generation (Optional)

The FIR coefficients are generated offline using Python.

To regenerate the coefficients:

```
cd src
python3 filter_design.py
```

This script designs a band-pass Butterworth FIR filter with:
- 64 taps
- Cutoff frequencies: 5–50 Hz
- Fixed-point scaling (Q15)

⚠️ If you do not modify the filter parameters, this step is optional.

## Running the Simulation
### Compile RTL + Testbench

From the root directory:
```
make sim

```

or manually:

```
iverilog -g2005-sv \
    -o sim.out \
    src/fir.v \
    src/tb_fir_tkeo_chain.v
```

### Run the Simulation

```
vvp sim.out

```

This will:
- Read input samples from test_files/
- Process them through the FIR + TKEO chain
- Generate a waveform file: wave.vcd

### Visualize with GTKWave
```
gtkwave wave.vcd
```

Recommended signals to inspect:
- data_in
- fir_out
- tkeo_out
- window_done
- internal FIR signals (adder tree / pipeline stages)

## Test Vectors

Two types of test signals are provided:
- Real LFP recordings (test_files/lfp/)
- Synthetic noise signals (test_files/synthetic_noise/)

You can switch input files directly inside the testbench:
```
$fopen("test_files/lfp/...", "r");
```

# Conclusions
Architecture is optimized for:
- Reduced critical path
- Lower switching activity
- Area-aware design trade-offs

The testbench accounts for multi-cycle FIR latency
