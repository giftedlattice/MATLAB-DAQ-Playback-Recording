# MATLAB DAQ Playback & Recording

MATLAB laboratory utilities for **National Instruments (NI) DAQ-based acoustic stimulus playback, externally TTL-triggered microphone acquisition, sweep generation, and exploratory trial management**.

> **Status: experimental / hardware validation pending.** The scripts have been inventoried and reviewed, but have not been executed or tested against your specific DAQ hardware. Do not assume exact trigger-to-output latency, timing alignment, or calibrated output voltage without measurement.

## Repository layout

| Directory | Contents | Purpose |
|---|---|---|
| [`acquisition/`](acquisition/) | `BatPlaybackRecordGUI.m`, `mic_array_playback.m` | Combined stimulus playback and microphone recording workflows |
| [`recording_examples/`](recording_examples/) | `mic_array_simple.m`, `mic_array_simple_plotting.m` | Minimal externally triggered recording demonstrations |
| [`stimulus_tools/`](stimulus_tools/) | `generate_tone.m`, `produce_signal.m`, `playcue_choice.mlx`, `playcuedemo.mlx` | Stimulus generation and standalone playback |
| [`stimuli/examples/`](stimuli/examples/) | Two example WAV files | Audio assets used by `playcue_choice.mlx` |
| [`tests/`](tests/) | Validation planning | Place for future offline and NI hardware tests; no tests included yet |

Each program is a separate MATLAB entry point. **These are not yet a unified application**; the scripts share experimental themes but have differing hardware IDs, timing, and stimulus-input conventions.

## Requirements

- MATLAB with the **Data Acquisition Toolbox** and a compatible version of its `daq("ni")` interface.
- NI-DAQmx driver and supported National Instruments analog input/output hardware; an external TTL source for the triggered recording workflows.
- **Signal Processing Toolbox functionality** is used by `resample` and/or `spectrogram` in some workflows.
- Valid stimulus `.wav` or `.mat` files, depending on the program. MATLAB Live Script support for `.mlx` examples.
- `numpy`/Python are **not** required to run these MATLAB scripts.

The example settings refer variously to `PXI1Slot3` and `Dev1`. These are **different configuration values in different scripts**, not interchangeable defaults. Verify hardware IDs using your MATLAB/NI setup before running.

## Getting started

1. Clone or download this repository, keeping the folder structure.
2. Read the README in the folder containing the program of interest.
3. Review the program's **User Configuration** variables and set device IDs, channels, trigger source, paths, sampling rate, recording duration, and output amplitude.
4. Connect and electrically validate the NI hardware, microphone channels, loudspeaker chain, and external trigger.
5. Begin with a dummy signal/test setup. Verify timing and amplitudes with suitable test equipment before experimental use.

Example main GUI launch from MATLAB after adding the acquisition directory to the path:

```matlab
addpath('C:\path\to\MATLAB-DAQ-Playback-Recording\acquisition')
BatPlaybackRecordGUI
```

## Inputs and results

- `BatPlaybackRecordGUI.m` selects a **WAV** file. It saves MAT files under the configured `rootSaveDir/YYYYMMDD/BATID/` structure, with acquisition data, timestamps, stimulus samples, and metadata; optionally plots and saves PNGs.
- `mic_array_playback.m` selects **MAT** stimulus files (randomly by default), recording a fixed-duration acquisition and saving MAT data and optional PNG figures in MATLAB's **current working directory**.
- Minimal recording examples save triggered microphone data to `mic_YYYYMMDD_trialNN.mat`; the plotting variant also saves PNGs.
- Stimulus utilities produce DAQ output; they do not record microphone trials themselves.

## Important limitations

- The main GUI uses `addlistener(d, "DataAvailable", ...)` together with `daq("ni")`, `preload`, and `start(..., "repeatoutput")`. **Confirm that this combination is supported by your MATLAB release and DAQ configuration**, and that triggering and data capture behave as intended.
- The GUI's `trialStartTime` is assigned when the run is armed, **not measured when the TTL edge arrives**. The stored output duration is derived from recorded data, not a direct measure of the number of repeat-playback cycles.
- Raw samples are appended to growing memory buffers in the main GUI; long multichannel acquisitions may be expensive in memory.
- Multiple scripts normalize waveforms without calibrating the entire loudspeaker/acoustic chain. Verify safe and accurate **analog voltage** independently.
- The two sweep generators explicitly use `repeatoutput`. Their own comments flag unwanted repetition; do not treat output as a verified single sweep.
- Some examples use `while true` and require manual interruption; interruption may bypass normal cleanup.
- `playcue_choice.mlx` currently searches for its two WAVs in MATLAB's **current directory**. Moving the WAVs into `stimuli/examples/` requires setting the working directory accordingly or editing the script's path.
- Avoid committing raw experimental recordings, subject identifiers, or other sensitive datasets to a public repository. Choose and document an appropriate data-storage location separately.

## Development status

**Source archive organized for version control; no acquisition, synchronization, voltage, or safety validation has been performed as part of this documentation.** The priority is to run and verify each independent workflow before refactoring or merging them.
