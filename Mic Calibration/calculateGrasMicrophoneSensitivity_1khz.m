function GRAS_sens = Copy_of_calculateGrasMicrophoneSensitivity_1khz(Gras_Gain)
    %% Calculate the sensitivity of the GRAS mic
    % This function loads waveform data from .mat files in a selected directory, 
    % calculates the RMS values based on the microphone gain, determines the mean RMS value,
    % and computes the sensitivity of the microphone in dB.

    %% Select the directory containing the calibration data
    calib_dir = uigetdir('D:\_Mic Calibration\20250816\Recordings\1khz\8th', 'Select Folder Containing 1kHz Recordings');
    if calib_dir == 0
        fprintf('No directory selected. Exiting function...\n');
        return;
    end

    %% Verify the directory contains .mat files
    matFiles = dir(fullfile(calib_dir, '*.mat'));
    if isempty(matFiles)
        fprintf('No .mat files found in the selected directory. Please select a directory with .mat files.\n');
        return;  % Exit if no .mat files are found
    end

    %% Initialize variables for processing
    pulse_rms = [];

    %% Process each .mat file in the directory
    for k = 1:length(matFiles)
        filename = fullfile(calib_dir, matFiles(k).name);  % Construct full path to each .mat file

        try
            % Load the calibration data file
            cal_data = load(filename);

            % Extract waveform data and sampling frequency
            data = cal_data.sig;  % Assume 'sig' is the waveform data variable name
            fs_cal = cal_data.fs;  % Assume 'fs' is the sampling frequency variable name

    %% Calculate RMS based on microphone gain
            switch Gras_Gain
                case 40
                    RMS = rms(data) / 100; % Correct for 40 dB amplification, factor is 10^(40/20)
                case 20
                    RMS = rms(data) / 10;  % Correct for 20 dB amplification, factor is 10^(20/20)
                case 0
                    RMS = rms(data);       % No gain correction needed
                otherwise
                    error('Unsupported microphone gain. Please use 0, 20, or 40 dB.');
            end


            % Collect RMS values
            pulse_rms = [pulse_rms; RMS];

        catch ME
            fprintf('Failed to load or process %s: %s\n', filename, ME.message);
            continue;  % Skip to the next file if an error occurs
        end
    end

    %% Calculate the mean RMS value and microphone sensitivity
    mean_pulse_rms = mean(pulse_rms);
    GRAS_sens = 20 * log10((mean_pulse_rms * 10) / (2e-5 * (10^(94/20))) * 10^-3);

    %% Display and return the calculated sensitivity
    disp(['Calculated GRAS Microphone Sensitivity: ', num2str(GRAS_sens), ' dB']);
    return;  % Ensure this returns the calculated value
end
