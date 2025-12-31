#!/usr/bin/env python3
"""
LibreLane Flow Runner for FIR Filter
Executes the complete RTL-to-GDSII flow using LibreLane (OpenLane)

Usage:
    # Run full flow
    python3 run_librelane.py
    
    # Run specific step
    python3 run_librelane.py --step synthesis
    python3 run_librelane.py --step floorplan
    
    # Run up to a specific step
    python3 run_librelane.py --until routing
"""

import os
import sys
import shutil
import argparse
from pathlib import Path

try:
    import librelane
    from librelane.config import Config
    from librelane.state import State
    from librelane.steps import Step
except ImportError:
    print("Error: LibreLane is not installed.")
    print("Install with: pip install librelane")
    print("Or use nix-shell if you have Nix installed.")
    sys.exit(1)

# -----------------------------------------------------------------------------
# Environment Setup
# -----------------------------------------------------------------------------

def setup_environment():
    """Setup environment for LibreLane execution"""
    nix_paths = [
        "/nix/var/nix/profiles/default/bin",
        f"{os.environ.get('HOME')}/.nix-profile/bin",
    ]
    
    os.environ["PATH"] = ":".join(nix_paths) + ":" + os.environ["PATH"]
    
    # Check for required tools
    if not shutil.which("yosys"):
        print("Warning: Yosys not found in PATH")
    if not shutil.which("openroad"):
        print("Warning: OpenROAD not found in PATH")
    
    print(f"Using LibreLane version: {librelane.__version__}")

# -----------------------------------------------------------------------------
# Flow Steps
# -----------------------------------------------------------------------------

FLOW_STEPS = [
    ("synthesis", "Yosys.Synthesis"),
    ("floorplan", "OpenROAD.Floorplan"),
    ("tap_endcap", "OpenROAD.TapEndcapInsertion"),
    ("io_placement", "OpenROAD.IOPlacement"),
    ("pdn", "OpenROAD.GeneratePDN"),
    ("global_placement", "OpenROAD.GlobalPlacement"),
    ("detailed_placement", "OpenROAD.DetailedPlacement"),
    ("cts", "OpenROAD.CTS"),
    ("global_routing", "OpenROAD.GlobalRouting"),
    ("detailed_routing", "OpenROAD.DetailedRouting"),
    ("gds_export", "KLayout.StreamOut"),
]

def run_step(state, step_id, **kwargs):
    """Run a single LibreLane step"""
    print(f"\n{'='*80}")
    print(f"Running: {step_id}")
    print(f"{'='*80}\n")
    
    try:
        step_cls = Step.factory.get(step_id)
        step = step_cls(state_in=state, **kwargs)
        step.start()
        return step.state_out
    except Exception as e:
        print(f"Error running {step_id}: {e}")
        raise

def run_flow(config_path, single_step=None, until_step=None):
    """Run the LibreLane flow"""
    
    # Load configuration
    print(f"Loading configuration from: {config_path}")
    Config(config_path)
    
    state = State()
    
    # Determine which steps to run
    steps_to_run = []
    if single_step:
        # Find the specific step
        for name, step_id in FLOW_STEPS:
            if name == single_step:
                steps_to_run = [(name, step_id)]
                break
        if not steps_to_run:
            print(f"Error: Step '{single_step}' not found")
            print(f"Available steps: {', '.join([name for name, _ in FLOW_STEPS])}")
            sys.exit(1)
    elif until_step:
        # Run all steps until the specified step (inclusive)
        for name, step_id in FLOW_STEPS:
            steps_to_run.append((name, step_id))
            if name == until_step:
                break
        if not any(name == until_step for name, _ in steps_to_run):
            print(f"Error: Step '{until_step}' not found")
            sys.exit(1)
    else:
        # Run all steps
        steps_to_run = FLOW_STEPS
    
    # Execute steps
    for step_name, step_id in steps_to_run:
        print(f"\n>>> Step: {step_name}")
        state = run_step(state, step_id)
    
    # Print results
    print(f"\n{'='*80}")
    print("FLOW COMPLETE")
    print(f"{'='*80}\n")
    
    views = state.get_views()
    
    if views:
        print("Generated files:")
        for view_name, view_path in views.items():
            if view_path:
                print(f"  {view_name:15s}: {view_path}")
    
    return state

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Run LibreLane ASIC flow for FIR Filter"
    )
    parser.add_argument(
        "--config",
        default="config.json",
        help="Path to config.json (default: config.json)"
    )
    parser.add_argument(
        "--step",
        help="Run only a specific step (e.g., synthesis, floorplan, routing)"
    )
    parser.add_argument(
        "--until",
        dest="until_step",
        help="Run all steps up to and including the specified step"
    )
    
    args = parser.parse_args()
    
    # Setup environment
    setup_environment()
    
    # Get absolute path to config
    script_dir = Path(__file__).parent.resolve()
    config_path = script_dir / args.config
    
    if not config_path.exists():
        print(f"Error: Config file not found: {config_path}")
        sys.exit(1)
    
    # Change to script directory for execution
    os.chdir(script_dir)
    
    # Run the flow
    try:
        run_flow(str(config_path), single_step=args.step, until_step=args.until_step)
        print("\n✓ Flow completed successfully")
    except Exception as e:
        print(f"\n✗ Flow failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
