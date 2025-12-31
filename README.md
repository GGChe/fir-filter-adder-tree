# FIR Filter with Adder Tree Optimization

## Overview
This repository contains the RTL implementation and verification environment for an optimized FIR filter architecture, targeting low-power and efficient VLSI designs. The project focuses on optimizing a classic FIR filter using techniques such as adder-tree based accumulation, pipelining, and area-aware design decisions.

For efficient resource utilization, the FIR implements an adder tree. This adder tree aims to improve latency by reducing the critical path (data arrival time and data required time). An example of the architecture is shown in the following figure.

![FIR Filter Architecture](resources/fir_architecture.drawio.svg)

## Key Features
- Adder-tree based accumulation for balanced critical path
- Pipelining and architectural restructuring to improve timing
- Clock-gating and area-aware design choices for low switching activity
- Verilog RTL with simulation and verification flows (Icarus Verilog, GTKWave, cocotb)

## Installation

### Install System Tools (Ubuntu / Debian)

```bash
sudo apt update
sudo apt install -y iverilog gtkwave make
```

### Setup Python Environment

Ensure you have Poetry installed. Then, run the following in the project root:

```bash
# Install dependencies into a virtual environment
poetry install

# Activate the virtual environment
poetry shell
```

## FIR Coefficient Generation

The FIR coefficients are generated offline using Python.

To regenerate coefficients:

```bash
cd src
python3 filter_design.py
```

**Notes:**
- The script designs a band-pass FIR filter using fixed-point (Q15)
- The number of taps and cutoff frequencies are configurable (default: 5–50 Hz)
- If parameters are unchanged, regeneration is optional

## Running Simulations

### Verilog simulation with Iverilog & GTKWave

The Verilog testbench provides cycle-accurate simulation and waveform visualization.
The testbench is localized at `tb/verilog/tb_fir.v`. We can run the simulation with the following commands.

```bash
make
vvp sim.out
gtkwave wave.vcd
```

**Workflow:**
1. Compile Verilog RTL and testbench with Icarus Verilog
2. Execute simulation to generate `wave.vcd` waveform file
3. Inspect signals in GTKWave for timing analysis, data flow verification, and adder-tree accumulation behavior
4. Validate coefficient loading, pipeline stages, and output correctness

**Verification Scope:**
- Clock and reset behavior
- FIR coefficient initialization
- Input/output data alignment across pipeline stages
- Critical path timing and latency

### cocotb Verification with Python

The cocotb testbench automates functional verification against a Python reference model. The cocotb testbenc is in `tb/cocotb/test_fir.py`. This code runs the test for different simulated signals. 

```bash
cd tb/cocotb
make
```

**Workflow:**
1. Drive Q15 fixed-point test vectors to the FIR module
2. Capture RTL outputs and compare against Python golden reference
3. Generate HTML reports, plots, and detailed logs
4. Verify numerical accuracy and filter behavior across test datasets

### Test Vectors

Provided datasets:
- Real neural LFP recordings: `test_files/lfp`
- Synthetic signals and noise: `test_files/synthetic_noise`

Input files can be switched in testbench configuration.

## Conclusion

The FIR architecture is optimized for:
- Reduced critical path using balanced adder trees
- Lower switching activity through pipelining and gating
- Area-efficient implementation suitable for neuromorphic signal processing

Both Verilog and cocotb testbenches are supported for flexible verification.

