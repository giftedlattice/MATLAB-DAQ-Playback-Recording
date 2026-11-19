# Triggered Microphone Recording Examples

Minimal NI DAQ MATLAB scripts for microphone recordings initiated by an **external rising-edge TTL trigger**. Neither program plays an audio stimulus.

## Files

| File | Behavior | Output |
|---|---|---|
| `mic_array_simple.m` | Configures selected differential analog inputs, waits for a trigger, records a short interval, then repeats | `mic_YYYYMMDD_trialNN.mat` containing `data` and `fs` |
| `mic_array_simple_plotting.m` | Same acquisition plus per-channel waveform/spectrogram plots | MAT file plus `micFig_YYYYMMDD_trialNN.png` |

## Defaults (in both scripts)

- NI device: `PXI1Slot3`.
- Input(s): `ai0` with label `Mic1`, configured for differential acquisition; arrays of channels/labels can be substituted.
- Sample rate: **250,000 Hz**.
- Recording duration: **0.050 seconds (50 ms)** per trigger.
- External trigger: `PFI0`, **RisingEdge**; configured timeout 300 seconds.
- Trial index begins at 1 for each new script execution.

## Running

1. Connect a compatible microphone acquisition chain and NI DAQ with an external TTL source.
2. Open one of the scripts in MATLAB and change `deviceID`, `channelIDs`, `channelLabels`, `recordDuration` and trigger settings as needed.
3. Set MATLAB's **current directory** to the intended output location; run the script.
4. Send a valid external trigger. Results are saved in the current directory.
5. Stop with MATLAB interruption when finished; both scripts currently use `while true` and have **no dedicated Stop button**.

## Limitations / next improvements

- These are equipment-dependent examples, not validated continuous acquisition systems.
- The scripts recreate and reset the DAQ for every trial. Confirm this works with the installed hardware and MATLAB release.
- Recording files can be overwritten on subsequent runs when the date and trial number repeat.
- In the plotting example, spectrogram generation uses signal-processing functionality.
- Add a controlled stop mechanism, `try`/`finally`-style cleanup (`onCleanup` where appropriate), and validated timing measurements before routine experiments.

**Status:** Standalone examples; hardware behavior and time synchronization unverified.
