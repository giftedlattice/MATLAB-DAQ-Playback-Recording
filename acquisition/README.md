# Playback + Microphone Acquisition

Two **independent** MATLAB approaches to playback combined with NI DAQ microphone recording. These are alternative workflows, not two scripts that must run together.

## `BatPlaybackRecordGUI.m` — operator-controlled recording

**Purpose:** A MATLAB UI for a selected bat ID and WAV stimulus. Configures analog microphone inputs and an analog output, arms a **rising-edge** digital start trigger, queues a repeating audio waveform, and collects incoming recordings in memory until the operator presses **Stop Recording**.

**As coded:**

1. Launch `BatPlaybackRecordGUI` to open the GUI; enter BAT ID and browse for a `.wav` stimulus.
2. Select **Go / Arm + Play**; the program creates `<rootSaveDir>/YYYYMMDD/<BATID>/` and finds the next recorded trial number.
3. WAV audio is converted to mono if necessary, resampled to `fs` when needed, normalized by its peak, and preloaded for repeat playback.
4. The script starts a NI DAQ session configured for an external digital start trigger on `PFI0`.
5. Select **Stop Recording** to stop and save `data`, `timestamps`, `signal` and `meta` to a `rec_..._trialNN.mat` file; optional waveform/spectrogram PNGs are generated.

**Default settings:** NI device `PXI1Slot3`; mic analog input `ai0` (differential, label `Mic1`); output `ao0`; 250,000 Hz; external trigger `PFI0`, **RisingEdge**; trigger wait timeout 300 s; plotting on. The root output folder and default WAV folder are **hardcoded Windows paths that must be changed**.

**Validation concerns:** The code uses `daq("ni")` and a `DataAvailable` listener with `start(d, "repeatoutput")`; test this API combination and the relationship between trigger, output start, and acquisition on your system. `trialStartTime` records arming time, not a hardware-measured TTL time. Data buffers grow in RAM; hardware-level time alignment is unverified.

## `mic_array_playback.m` — fixed-duration triggered trials

**Purpose:** A separate script for triggered playback and acquisition, using `.mat` stimulus files. It selects a file **randomly by default**, or prompts for a specific file when `selectSpecificFile = true`.

**As coded:** each trial loads a numeric vector (prioritizing the variable names `signal`, `audio`, `y` or `x`); chooses the original sample rate from `Fs` or assumes the DAQ rate; resamples if needed; trims or zero-pads to `recordDuration`; normalizes to peak magnitude; and invokes `[data, timestamps] = readwrite(d, signal)`. It saves the trial to `rec_<micTag>_YYYYMMDD_trialNN.mat` in MATLAB's current directory and optionally saves a PNG with waveforms and spectrograms.

**Default settings:** `PXI1Slot3`, `ai0`, `ao0`, `PFI0` rising-edge, 250,000 Hz, **50 ms** record/playback duration, 300 s trigger timeout, plotting on, `selectSpecificFile = false`, `trialNum = 1`.

**Validation concerns:** `audioDir` is a hardcoded Windows location; the `while true` loop has no dedicated Stop GUI; repeated runs can reuse output filenames; actual acquisition and playback synchronization must be verified on hardware. The signal is peak-normalized without a target voltage calibration.

## Requirements / operation

- MATLAB, Data Acquisition Toolbox (compatible modern `daq("ni")` API), NI-DAQmx, suitable NI analog I/O hardware, and an external TTL trigger.
- `resample` and `spectrogram` require applicable signal-processing functionality.
- Configure and verify device, pinout, input range, output level, channel names, trigger edge, and recording paths before use.
- Launch `BatPlaybackRecordGUI` or run `mic_array_playback.m` **individually**, not at the same time on the same DAQ.

**Status:** Experimental. Do not regard recorded timestamps or stimulus/audio alignment as hardware-verified without a controlled timing test.
