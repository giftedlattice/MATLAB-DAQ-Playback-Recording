# Example WAV Stimuli

The source ZIP includes these files:

| File | Intended stimulus | Header information |
|---|---|---|
| `LinearSweeps_8_40_V1.wav` | Linear frequency sweeps (according to filename) | Mono, 250,000 samples/s, 16-bit PCM, about 10.61 s |
| `White_Noise_BP_8_40_V1.wav` | Band-pass white noise (according to filename) | Mono, 250,000 samples/s, 16-bit PCM, about 10.85 s |

These names are explicitly referenced by `stimulus_tools/playcue_choice.mlx`.

## Using the assets

The Live Script currently calls `isfile(filename)` and `fullfile(pwd, filename)`; it therefore needs the WAV files to be in MATLAB's **current working directory**. After moving them into this folder, either set the current folder to `stimuli/examples/` before playback, or revise `playcue_choice.mlx` to build the input path to this directory explicitly.

## Validation and data policy

- Filenames describe intended bands, but actual waveform spectra, output voltage and speaker calibration should be checked experimentally.
- Confirm rights to share these stimuli before making a public repository.
- These are **stimulus files**, not original microphone recordings.

**Status:** Example stimuli, not validated calibrated acoustic reference signals.
