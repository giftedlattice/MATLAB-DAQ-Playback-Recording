function analyzeMicrophoneSensitivity_regularMic(freqs, pulse_dur, pulse_interval,gain_pet, GRAS_sens, gain_speaker)
    % Load the calibrated mic pulses and pxx_cal_mean
    [file,path] = uigetfile('*.mat','Select the pulse_cal.mat file');
    if isequal(file,0)
        error('No file selected, function will terminate.');
    else
        load(fullfile(path, file), 'pulse_cal', 'fs_cal', 'pxx_cal_mean');
    end

    calib_dir = uigetdir('D:\_Mic Calibration\Pipeline\Recordings\360', 'Select folder where Mic Recordings are');
    if calib_dir == 0 
        error('No directory selected, function will terminate.');
    end
    
    matFiles = dir(fullfile(calib_dir, '*.mat'));
    fnames = {matFiles.name};
    % Make sure fnames is not empty
    if isempty(fnames)
        error('No .mat files found in the directory.');
    end
    
    % Get the sensitivity of each pet mic
    for findx = 1:length(fnames)
        fname = fnames{findx};
        DIAG = 1; % Create diagonal matrix or get diagonal elements of matrix
        use_fft = 0; % otherwise use pwelch

        % Load individual microphone file
        try
            data = load(fullfile(calib_dir, fname));
            sig = data.sig; % Assuming 'sig' is the variable name in the .mat file
            fs = data.fs; % Assuming 'fs' is the variable name in the .mat file


        catch
            warning('Failed to load %s, it may not contain sig and fs.', fname);
            continue;
        end

        data_comp = sig / gain_pet; % Compensate for gain

        % Square the compensated data, Squares the compensated signal to emphasize peaks and uses the findpeaks function to locate peaks that are at least half the maximum value and separated by at least pulse_interval * fs (sampling frequency).
        data_comp_sq = data_comp.^2;
        [pks, locs] = findpeaks(data_comp_sq, 'minpeakheight', max(data_comp_sq)/2, 'minpeakdistance', pulse_interval * fs);
        if length(locs) ~= 4
            disp('Didn''t find 50 pulses in recording');
        end

        % Plot the compensated squared data
        if DIAG
            figure(2), clf;
            plot(data_comp_sq);
            hold on;
            plot(locs, pks, '*');
        end

        % Allocate arrays for pulses and PSDs
        pulse_pet = nan(length(locs), pulse_dur * fs * 2 + 1);
        pxx = nan(length(locs), length(freqs));

        % Process each located peak (amended during by Jake)
        half_win = round(pulse_dur * fs);  % Half-window length in samples
        
        for pp = 1:length(locs)
            start_idx = max(1, locs(pp) - half_win);
            end_idx   = min(length(data_comp), locs(pp) + half_win);
        
            % Preallocate NaN padding if the segment isn't full length
            segment = nan(1, 2*half_win + 1);
            segment(1:(end_idx - start_idx + 1)) = data_comp(start_idx:end_idx);
            pulse_pet(pp, :) = segment;
        
            % Calculate power spectral density
            if use_fft
                % Replace this with your real FFT/periodogram method if needed
                [Pxx, ~] = periodogram(segment, [], freqs, fs);
                pxx(pp, :) = Pxx;
            else
                pxx(pp, :) = pwelch(segment, 128, 120, freqs, fs);
            end
        
            % Plot diagnostics if needed
            if DIAG
                figure(1), clf;
                subplot(2,1,1);
                plot(segment);
                title(sprintf('Pulse %d', pp));
                subplot(2,1,2);
                spectrogram(segment, 128, 120, 1e3, fs, 'yaxis');
                colormap('jet');
                pause(0.05);
        
                figure(30), clf;
                plot(freqs/1e3, 10*log10(pxx(pp, :)));
                xlabel('Frequency (kHz)');
                ylabel('Power/Frequency (dB/Hz)');
            end
        end


        % Calculate mean PSD
        pxx_mean = mean(pxx);

        % Plot mean PSD
        if DIAG
            figure(5), clf;
            plot(freqs/1e3, 10*log10(pxx_mean));
            grid on;
        end

        % Calculate standardized PSD and sensitivity
        pxx_stand = pxx_mean ./ pxx_cal_mean;
        sens_pet_dB = 10 * log10(pxx_stand) + GRAS_sens;

        % Plot the final sensitivity graph
        if DIAG
            figure(8), clf;
            plot(freqs/1e3, sens_pet_dB);
            grid on;
            xlim([freqs(1) freqs(end)]/1e3);
            ylim([-45 -10]);
        end

        % Save the results (edited by Jake)
        % Extract mic and position from the filename
        micToken = regexp(fname, '(Mic_[^_]+)', 'match', 'once'); % e.g. Mic_SFR-M4
        posToken = regexp(fname, '(Pos_\d+)', 'match', 'once');   % e.g. Pos_270
        
        % Fallbacks if not found
        if isempty(micToken), micToken = 'Mic_UNKNOWN'; end
        if isempty(posToken), posToken = 'Pos_UNKNOWN'; end
        
        % Create a safe file name
        Fname = sprintf('sens_pet_dB_%s_%s', micToken, posToken);
        
        % Save
        save(Fname, 'sens_pet_dB', 'pulse_cal', 'fs_cal', 'pxx_cal_mean', 'use_fft');

    end
end