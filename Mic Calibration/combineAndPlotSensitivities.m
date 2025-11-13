function combineAndPlotSensitivities(freq_start,freq_step,num_freqs, freq_index)
    folder_path = uigetdir('D:\_Mic Calibration\Pipeline', 'Select folder where the sensitivy files are');
    if folder_path == 0, error('No directory selected, function will terminate.'); end    

    freq = (freq_start + (0:num_freqs-1) * freq_step).';

    % Use num_freqs instead of hard-coded 91
    bp_combined = zeros(num_freqs, 360);
    filled_mask = false(1, 360);        % <-- track which columns are filled
    theta = (0:359).';

    % angles: 270->350 then 0->90
    angles = [270:10:350, 0:10:90];

    for angle = angles
        searchPattern = sprintf('*Pos_%03d.mat', angle);
        matchFile = dir(fullfile(folder_path, searchPattern));
        if isempty(matchFile)
            warning('No file found for angle %03d — skipping...', angle);
            continue;
        end
        file_name = fullfile(folder_path, matchFile(1).name);

        S = load(file_name, 'sens_pet_dB');
        if ~isfield(S,'sens_pet_dB')
            warning('Variable "sens_pet_dB" not found in %s — skipping...', file_name);
            continue;
        end

        sensitivities = S.sens_pet_dB(:);  % column vector
        if numel(sensitivities) ~= size(bp_combined,1)
            warning('Row length mismatch at %03d — skipping...', angle);
            continue;
        end

        % fill the main column
        bp_combined(:, angle+1) = sensitivities;
        filled_mask(angle+1) = true;

        % infill forward up to +10°, clamped to 360
        start_col = angle + 2;
        end_col   = min(angle + 10, 360);
        if start_col <= 360
            N = end_col - start_col + 1;
            if N > 0
                bp_combined(:, start_col:end_col) = repmat(sensitivities, 1, N);   % <-- fix shape
                filled_mask(start_col:end_col) = true;
            end
        end

        % wrap-around infill (e.g., 350 -> columns 1:9)
        wrap_cols = angle + 10 - 360;   % will be 0..9 when angle is 350
        if wrap_cols > 0
            bp_combined(:, 1:wrap_cols) = repmat(sensitivities, 1, wrap_cols);
            filled_mask(1:wrap_cols) = true;
        end
    end

    % pick one frequency row
    if freq_index < 1 || freq_index > size(bp_combined,1)
        error('freq_index (%d) must be between 1 and %d', freq_index, size(bp_combined,1));
    end
    sensitivities_data = bp_combined(freq_index, :);

    % plot only measured columns
    sens_plot = sensitivities_data;
    sens_plot(~filled_mask) = NaN;  % <-- hide unmeasured angles

    figure;
    pax = polaraxes; hold(pax,'on');
    theta_rad = deg2rad(theta);
    polarplot(pax, theta_rad, sens_plot, 'LineWidth', 2);

    % robust r-limits (ignore NaNs)
    valid = sens_plot(~isnan(sens_plot));
    if ~isempty(valid)
        rlim(pax, [min(valid)-1, max(valid)+1]);   % or rlim([-45 -10]) if you prefer fixed
    end
    title(sprintf('Sensitivities at %d Hz', freq(freq_index)));

    % colorbar on a single line plot isn't meaningful—safe to omit
    % colormap('jet'); colorbar;

    save('polar_sens_mic22.mat', 'freq', 'theta', 'bp_combined');
end
