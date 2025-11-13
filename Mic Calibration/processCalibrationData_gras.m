function Copy_of_processCalibrationData_gras(freqs, pulse_dur, pulse_interval,gain_speaker)
    %% Process Calibration Data
    % This function computes the mean power spectral density across all pulses.
    % Optionally displays a plot of the mean power spectral density.
    % Saves important variables to a .mat file for later use.
    % Taken from Moss lab, edited by @Finger, Nikita 2024

   

    DIAG = 1;  % Create a diagonal matrix for debugging visualization

    use_fft = 0; 

    % Prompt user to select the directory containing the calibration data
    calib_dir = uigetdir('D:\_Mic Calibration\20250816\Recordings\1khz\8th', 'Select Folder Containing Gras Recordings');
    if calib_dir == 0 
        fprintf('No directory selected. Exiting function...\n');
        return;
    end

    % Load all .mat files in the selected directory
    matFiles = dir(fullfile(calib_dir, '*.mat'));
    if isempty(matFiles)
        fprintf('No .mat files found in the selected directory.\n');
        return;
    end

    pulse_cal = []; % Matrix to store processed calibration pulses 

    %% Process each .mat file found
    for k = 1:length(matFiles)
        filename = fullfile(calib_dir, matFiles(k).name);  % Full path to each .mat file

        % Load the calibration data
        try
            cal_data = load(filename);
            data = cal_data.sig; % waveform data
            fs_cal = cal_data.fs; % Extract sampling frequency from loaded data 

            % Perform gain compensation and DC removal
            gain_cal = db2mag(gain_speaker); % Convert dB into magnitude
            data_comp = (data ./ gain_cal) - mean(data ./ gain_cal); % Compensate for gain and remove DC component

            % Square the data to emphasize larger values
            data_comp_sq = data_comp.^2;
            [pks, locs] = findpeaks(data_comp_sq, 'minpeakheight', max(data_comp_sq)./2, 'minpeakdistance', pulse_interval * fs_cal);

            % Extract pulse around each peak
            for pp = 1:length(locs)
                pulse_cal(end+1,:) = data_comp(locs(pp)-round(pulse_dur * fs_cal * 0.7) : locs(pp)+round(pulse_dur * fs_cal * 1.3));

                % Optional visualization
                if DIAG
                    figure(4), clf;
                    subplot(2,1,1);
                    plot(pulse_cal(end,:));
                    subplot(2,1,2);
                    spectrogram(pulse_cal(end,:), 256, 250, 1e3, fs_cal, 'yaxis');
                    colormap('jet');
                    pause(.05);
                end
            end
        catch ME
            fprintf('Failed to load or process %s: %s\n', filename, ME.message);
            continue;
        end
    end

    % Calculate and plot power spectral density
    pxx_cal = nan(size(pulse_cal, 1), length(freqs));
    for pp = 1:size(pulse_cal, 1)
        if use_fft
            pxx_cal(pp, :) = periodogram(pulse_cal(pp, :), [], freqs, fs_cal);
        else
            pxx_cal(pp, :) = pwelch(pulse_cal(pp, :), 256, 250, freqs, fs_cal);
        end

        if DIAG
            figure(5), clf;
            plot(freqs / 1e3, pxx_cal(pp, :));
        end
    end
    pxx_cal_mean = mean(pxx_cal, 1);  % Calculate mean PSD

   % After calculating the mean PSD:
speaker_sens_dB = 10 * log10(pxx_cal_mean); % Convert mean PSD to dB

if DIAG
    figure(6), clf;
    plot(freqs / 1e3, speaker_sens_dB);
    grid on;
    
    % Define file name for the saved figure
    figName = 'speaker_sens_dB';
    
    % Prompt the user to select the folder to save the figure
    directory = uigetdir('C:\', 'Select Folder to Save Figure');
    if directory == 0 
        fprintf('No directory selected. Figure not saved.\n');
    else
        % Save the figure
        savefig(fullfile(directory, [figName, '.fig']));
        saveas(gcf, fullfile(directory, [figName, '.png']));
        disp(['Figure saved as ', fullfile(directory, [figName, '.png'])]);
    end
end

% Save the speaker_sens_dB to a .mat file
save(fullfile(directory, [figName, '.mat']), 'speaker_sens_dB');


    % Save results to .mat file
    save('pulse_cal.mat', 'pulse_cal', 'fs_cal', 'pxx_cal_mean', 'use_fft');
end
