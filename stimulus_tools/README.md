# Audio Stimulus Generation and Playback

Standalone MATLAB utilities for NI DAQ analog output. **No microphone acquisition is implemented in these four scripts.** The `.m` files create chirps; the `.mlx` Live Scripts select and output WAV stimuli.

## Programs

| Program | What it does | Key defaults |
|---|---|---|
| `generate_tone.m` | Generates a linear or logarithmic frequency sweep with 5 ms cosine onset/offset ramps | 8–35 kHz, **0.10 V peak-to-peak**, 1 s sweep, 250 kHz, `Dev1/ao0`; calls `repeatoutput` for 1 s |
| `produce_signal.m` | Near-identical sweep generator with different settings | 8–40 kHz, **0.25 V peak-to-peak**, 1 s sweep, 250 kHz, `Dev1/ao0`; calls `repeatoutput` for 5 s |
| `playcue_choice.mlx` | Offers **Linear Sweeps** or **White Noise** dialog and repeats/trims a WAV to configured duration | 120 s, 1.75 V nominal peak scaling, `Dev1/ao0` |
| `playcuedemo.mlx` | Opens a WAV chooser, pads or truncates audio to selected duration, and plays once through NI DAQ | 3 s, 0.25 V nominal peak scaling, `PXI1Slot3/ao0` |

The sweep scripts implement chirps with local helper functions (`createSweep` and `chirp_safe`); they do not call code in the other project folders.

## How to use

1. Open one script in MATLAB (Live Scripts must be opened with MATLAB Live Editor).
2. Edit the DAQ device ID, output channel, output amplitude and duration for the attached hardware.
3. For `playcue_choice.mlx`, place `LinearSweeps_8_40_V1.wav` and `White_Noise_BP_8_40_V1.wav` in **MATLAB's current working directory**, or **change the script** to load them from `../stimuli/examples/` after reorganization.
4. Run a single program and inspect the electrical waveform before connecting speakers or other experimental devices.

## Known issues

- Both chirp generators explicitly call `start(d, "repeatoutput")`, so they can loop a 1-second sweep. Their source comments flag this as undesirable for a truly single, continuous sweep. **Do not treat a requested running time as a single sweep duration.**
- Both `.mlx` programs contain comments that incorrectly describe the configured output scaling. The numeric values in the code are **1.75 V** for `playcue_choice.mlx` and **0.25 V** for `playcuedemo.mlx`; actual DAQ voltages depend on normalization and device configuration.
- The WAV utilities divide by the maximum audio magnitude without handling an all-zero recording; silence-only files may cause invalid scaling.
- `Dev1` and `PXI1Slot3` are hardcoded in different scripts. Check hardware support and update per program.
- Input file naming (8–40 kHz) describes intended stimulus content; actual spectra and acoustic output are not independently verified here.

**Status:** Independent exploratory utilities; voltage, signal continuity, and acoustic calibration pending validation.
