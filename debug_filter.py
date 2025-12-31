import numpy as np
import scipy.signal as signal

def analyze_filter():
    # Parameters
    fs = 2000
    fc = [5, 50]
    numtaps = 121
    
    # Re-design to see expected behavior
    nyquist = 0.5 * fs
    low_fc = fc[0] / nyquist
    high_fc = fc[1] / nyquist
    
    b_float = signal.firwin(numtaps, [low_fc, high_fc], pass_zero=False, window="hamming")
    
    # Calculate response at 100 Hz
    w, h = signal.freqz(b_float, worN=[100/nyquist*np.pi])
    gain_at_100 = np.abs(h[0])
    db_at_100 = 20*np.log10(gain_at_100)
    
    print(f"Design Parameters: Fs={fs}, Passband={fc} Hz, Taps={numtaps}")
    print(f"Expected Gain at 100 Hz: {gain_at_100:.4f} ({db_at_100:.2f} dB)")

    # Check actual HEX coeffs
    try:
        with open("fir_coeffs_q15.hex", "r") as f:
            lines = f.readlines()
        
        coeffs = []
        for line in lines:
            val = int(line.strip(), 16)
            if val > 32767:
                val -= 65536
            coeffs.append(val)
        
        coeffs = np.array(coeffs) / 32768.0
        
        w_hex, h_hex = signal.freqz(coeffs, worN=[100/nyquist*np.pi])
        gain_hex = np.abs(h_hex[0])
        db_hex = 20*np.log10(gain_hex)
        
        print(f"Actual HEX Coeffs Gain at 100 Hz: {gain_hex:.4f} ({db_hex:.2f} dB)")
        
    except Exception as e:
        print(f"Could not read HEX file: {e}")

if __name__ == "__main__":
    analyze_filter()
