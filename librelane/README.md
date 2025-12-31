# LibreLane Flow for FIR Filter (Adder Tree)

This directory contains the configuration and scripts needed to run the complete ASIC synthesis flow using LibreLane (OpenLane).

## Files

- **config.json**: LibreLane configuration for the FIR filter design

## Prerequisites

### 1. Install Nix (Recommended)

LibreLane and its dependencies (Yosys, OpenROAD, etc.) are best installed via Nix:

```bash
# Install Nix
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enter nix-shell with LibreLane
nix-shell -p librelane
```

### 2. Install PDK

You'll need the SkyWater 130nm PDK:

```bash
# Using volare (PDK manager)
pip install volare
volare enable sky130
```

### 3. Install LibreLane (if not using Nix)

```bash
pip install librelane
```

## Usage

### Run Full Flow

Execute the complete RTL-to-GDSII flow using the librelane CLI:

```bash
cd librelane
librelane config.json
```

This will run all steps in sequence:
1. Synthesis (Yosys)
2. Floorplan
3. Tap/Endcap insertion
4. I/O placement
5. Power distribution network (PDN)
6. Global placement
7. Detailed placement
8. Clock tree synthesis (CTS)
9. Global routing
10. Detailed routing
11. GDS export (KLayout)

### Run Specific Steps

Run individual steps by specifying the step name after the config file:

```bash
# Run only synthesis
librelane config.json Yosys.Synthesis

# Run only floorplan
librelane config.json OpenROAD.Floorplan

# Run only global placement
librelane config.json OpenROAD.GlobalPlacement

# Run only routing
librelane config.json OpenROAD.DetailedRouting
```

### Run Multiple Steps

You can chain multiple steps:

```bash
# Run synthesis through placement
librelane config.json \
    Yosys.Synthesis \
    OpenROAD.Floorplan \
    OpenROAD.TapEndcapInsertion \
    OpenROAD.IOPlacement \
    OpenROAD.GeneratePDN \
    OpenROAD.GlobalPlacement \
    OpenROAD.DetailedPlacement
```

## Configuration

The `config.json` file contains the design parameters:

- **Clock Period**: 15 ns (66.67 MHz)
- **Core Utilization**: 35%
- **PDK**: SkyWater 130nm (sky130A)
- **Standard Cell Library**: sky130_fd_sc_hd

You can modify these parameters in `config.json` as needed.

## Outputs

After running the flow, you'll find outputs in the `runs/` directory:

- **Synthesized Netlist**: `runs/RUN_<timestamp>/<step>/fir_filter.v`
- **DEF File**: `runs/RUN_<timestamp>/<step>/fir_filter.def`
- **GDS File**: `runs/RUN_<timestamp>/final/gds/fir_filter.gds`
- **Reports**: Timing, area, power reports in respective step directories

## Troubleshooting

**Error: Yosys/OpenROAD not found**
- Make sure you're in a nix-shell or have the tools installed in your PATH
- Run: `which yosys` and `which openroad` to verify

**Error: PDK not found**
- Install the SkyWater PDK using volare (see Prerequisites)
- Set PDK_ROOT environment variable if needed

**Synthesis errors**
- Check that `../src/fir.v` exists and is valid Verilog
- Review synthesis log in `runs/RUN_<timestamp>/1-yosys-synthesis/`

## Next Steps

After successful GDS generation:
- Run DRC (Design Rule Check) and LVS (Layout vs Schematic)
- Perform post-layout timing analysis
- Extract parasitics for accurate simulation
