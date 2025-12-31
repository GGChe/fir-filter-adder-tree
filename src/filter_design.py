import numpy as np
import scipy.signal as signal
import matplotlib.pyplot as plt

# ============================================================
# FIR design + quantization (Q1.15)
# ============================================================

def design_bandpass_fir_filter(
    fs: int,
    fc: list,
    numtaps: int,
    frac_bits: int = 15
):
    """
    Design bandpass FIR filter and quantize to Q1.<frac_bits>.
    Intended for Verilog FIR with arithmetic shift right by frac_bits.
    """

    nyquist = 0.5 * fs
    low_fc = fc[0] / nyquist
    high_fc = fc[1] / nyquist

    # --------------------------------------------------------
    # 1) Floating-point FIR prototype
    # --------------------------------------------------------
    b_float = signal.firwin(
        numtaps,
        [low_fc, high_fc],
        pass_zero=False,
        window="hamming"
    )

    # --------------------------------------------------------
    # 2) Quantize to Q1.15
    # --------------------------------------------------------
    scale = 1 << frac_bits
    b_q = np.round(b_float * scale).astype(np.int32)

    # Saturate to int16
    b_q = np.clip(b_q, -32768, 32767).astype(np.int16)

    # --------------------------------------------------------
    # 3) Frequency response after quantization
    # --------------------------------------------------------
    b_rec = b_q.astype(np.float64) / scale
    w, h = signal.freqz(b_rec, worN=8192, fs=fs)

    print("===================================")
    print("FIR quantization summary")
    print(f"  NTAPS        : {numtaps}")
    print(f"  Q format     : Q1.{frac_bits}")
    print(f"  Scale factor : {scale}")
    print(f"  Max coeff    : {np.max(b_q)}")
    print(f"  Min coeff    : {np.min(b_q)}")
    print(f"  Max |H(f)|   : {np.max(np.abs(h)):.4f}")
    print("===================================")

    return b_q, b_rec, b_float


# ============================================================
# Test signal
# ============================================================

def generate_test_signal(fs: int, duration: float, frequencies: list):
    t = np.arange(0, duration, 1 / fs)
    x = np.zeros_like(t)

    for f in frequencies:
        x += np.sin(2 * np.pi * f * t)

    return t, x / len(frequencies)


# ============================================================
# Coefficient export
# ============================================================

def export_coeffs_hex(coeffs: np.ndarray, filename: str):
    """
    Export coefficients in HEX (one per line).
    Compatible with $readmemh in Verilog.
    """
    with open(filename, "w") as f:
        for c in coeffs:
            f.write(f"{np.uint16(c):04X}\n")

    print(f"[OK] HEX coefficients written to {filename}")


def export_coeffs_decimal(coeffs: np.ndarray, filename: str):
    """
    Export coefficients in signed decimal (debug/reference).
    """
    with open(filename, "w") as f:
        for c in coeffs:
            f.write(f"{int(c)}\n")

    print(f"[OK] Decimal coefficients written to {filename}")


# ============================================================
# Main
# ============================================================

if __name__ == "__main__":

    # --------------------------------------------------------
    # Configuration
    # --------------------------------------------------------
    fs = 2000
    fc = [5, 50]
    numtaps = 121
    frac_bits = 15

    # --------------------------------------------------------
    # FIR design + quantization
    # --------------------------------------------------------
    b_q15, b_rec, b_float = design_bandpass_fir_filter(
        fs, fc, numtaps, frac_bits
    )

    # --------------------------------------------------------
    # Verification with test signal
    # --------------------------------------------------------
    t, x = generate_test_signal(fs, 2.0, [10, 100])
    y = signal.lfilter(b_rec, 1.0, x)

    # --------------------------------------------------------
    # Plots
    # --------------------------------------------------------
    fig = plt.figure(figsize=(14, 10))

    # Zeros
    ax1 = plt.subplot(2, 3, 1)
    z = np.roots(b_rec)
    ax1.scatter(np.real(z), np.imag(z), s=30)
    ax1.add_patch(plt.Circle((0, 0), 1, fill=False, linestyle="--"))
    ax1.set_title("Zero plot")
    ax1.axis("equal")
    ax1.grid()

    # Impulse response
    ax2 = plt.subplot(2, 3, 2)
    ax2.stem(b_rec, basefmt=" ")
    ax2.set_title("Impulse response")
    ax2.grid()

    # Magnitude
    ax3 = plt.subplot(2, 3, 3)
    w, h = signal.freqz(b_rec, fs=fs)
    ax3.plot(w, 20 * np.log10(np.maximum(np.abs(h), 1e-12)))
    ax3.set_title("Magnitude response (dB)")
    ax3.grid()

    # Phase
    ax4 = plt.subplot(2, 3, 4)
    ax4.plot(w, np.unwrap(np.angle(h)))
    ax4.set_title("Phase response")
    ax4.grid()

    # Input
    ax5 = plt.subplot(2, 3, 5)
    ax5.plot(t[:500], x[:500])
    ax5.set_title("Input signal")
    ax5.grid()

    # Output
    ax6 = plt.subplot(2, 3, 6)
    ax6.plot(t[:500], y[:500])
    ax6.set_title("Filtered output")
    ax6.grid()

    plt.tight_layout()
    plt.show()

    # --------------------------------------------------------
    # Export for RTL
    # --------------------------------------------------------
    export_coeffs_hex(b_q15, "fir_coeffs_q15.hex")
    export_coeffs_decimal(b_q15, "fir_coeffs_q15.txt")
