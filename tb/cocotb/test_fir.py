import os
import csv
import cocotb
import numpy as np
import plotly.graph_objects as go
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from plotly.subplots import make_subplots

FRAC_BITS = 15
SCALE = 1 << FRAC_BITS


def float_to_q15(x):
    x = np.clip(x, -0.999969, 0.999969)
    return np.round(x * SCALE).astype(np.int16)


def q15_to_float(q):
    return q.astype(np.int16) / float(SCALE)


# Resolve dataset folder relative to this file
DATASET_FOLDER = os.path.join(os.path.dirname(__file__), "../../test_files")


def load_dataset(signal_type="synthetic"):
    signals = {}

    if signal_type == "synthetic":
        fs = 2000.0
        duration = 1.0
        freqs = [10.0, 30.0, 100.0]

        for f in freqs:
            t = np.arange(0, duration, 1.0 / fs)
            x = np.sin(2 * np.pi * f * t)
            signals[f"sine_{int(f)}Hz"] = {
                "fs": fs,
                "t": t,
                "x_float": x,
                "x_q15": float_to_q15(x),
            }

    elif signal_type == "lfp":
        fs = 2000.0
        filenames = [
            "20170224_slice02_04_CTRL2_0005_16_int_downsampled_chunk_int16.txt",
        ]

        for name in filenames:
            data = np.loadtxt(f"{DATASET_FOLDER}/lfp/{name}", dtype=np.int16)
            signals[name] = {
                "fs": fs,
                "t": np.arange(len(data)) / fs,
                "x_float": q15_to_float(data),
                "x_q15": data,
            }

    else:
        raise ValueError("Unknown dataset")

    return signals


async def run_fir(dut, x_q15):
    # dut._log.debug
    print("Starting FIR simulation, applying reset...")
    # Reset
    dut.rst.value = 1
    dut.s_axis_fir_tdata.value = 0
    dut.s_axis_fir_tvalid.value = 0
    dut.m_axis_fir_tready.value = 1

    for _ in range(5):
        await RisingEdge(dut.clk)

    dut.rst.value = 0
    await RisingEdge(dut.clk)
    # print("Reset released. Feeding input samples...")

    fir_out = []

    for i, sample in enumerate(x_q15):
        dut.s_axis_fir_tdata.value = int(sample)
        dut.s_axis_fir_tvalid.value = 1
        await RisingEdge(dut.clk)

        if dut.m_axis_fir_tvalid.value:
            val = int(dut.m_axis_fir_tdata.value.signed_integer)
            fir_out.append(val)
            # print(f"Cycle {i}: In={int(sample)}, Out={val}")

    # Drain the pipeline
    dut.s_axis_fir_tvalid.value = 0
    # print("Input stream finished. Draining pipeline...")
    for i in range(300):
        await RisingEdge(dut.clk)
        if dut.m_axis_fir_tvalid.value:
            val = int(dut.m_axis_fir_tdata.value.signed_integer)
            fir_out.append(val)
            # print(f"Drain cycle {i}: Out={val}")

    print(f"FIR run complete. Collected {len(fir_out)} samples.")
    return np.array(fir_out, dtype=np.int16)



@cocotb.test()
async def test_fir_only(dut):
    """
    FIR-only verification:
      - Fixed-point correctness
      - Dataset-driven
      - CSV + Plotly output
    """

    # Clock @ 100 MHz
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    await Timer(1, units="ns")

    signals = load_dataset(signal_type="synthetic")

    for name, sig in signals.items():
        dut._log.info(f"Testing FIR with signal: {name}")

        t = sig["t"]
        x_float = sig["x_float"]
        x_q15 = sig["x_q15"]

        fir_q15 = await run_fir(dut, x_q15)
        fir_float = q15_to_float(fir_q15)

        csv_name = f"fir_output_{name}.csv"
        with open(csv_name, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["n", "t", "input_q15", "input_float", "fir_q15", "fir_float"])
            for i in range(len(fir_q15)):
                w.writerow([
                    i,
                    float(t[i]),
                    int(x_q15[i]),
                    float(x_float[i]),
                    int(fir_q15[i]),
                    float(fir_float[i]),
                ])

        dut._log.info(f"[{name}] CSV saved: {csv_name}")

        fig = make_subplots(
            rows=2,
            cols=1,
            shared_xaxes=True,
            subplot_titles=(
                "Float domain: Input vs FIR",
                "Q15 domain: Input vs FIR",
            ),
        )

        fig.add_trace(go.Scatter(x=t[:len(fir_float)], y=x_float[:len(fir_float)],
                                 name="Input (float)"), row=1, col=1)
        fig.add_trace(go.Scatter(x=t[:len(fir_float)], y=fir_float,
                                 name="FIR (float)"), row=1, col=1)

        fig.add_trace(go.Scatter(x=t[:len(fir_q15)], y=x_q15[:len(fir_q15)],
                                 name="Input Q15"), row=2, col=1)
        fig.add_trace(go.Scatter(x=t[:len(fir_q15)], y=fir_q15,
                                 name="FIR Q15"), row=2, col=1)

        fig.update_layout(
            height=800,
            width=1200,
            title=f"FIR response — {name}",
            legend=dict(orientation="h"),
        )

        html_name = f"fir_output_{name}.html"
        fig.write_html(html_name)

        dut._log.info(f"[{name}] Plot saved: {html_name}")

