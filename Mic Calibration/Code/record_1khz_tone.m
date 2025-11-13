% === SETUP ===
nReps = 20;                      % Number of recordings
duration_s = 1;                % Duration per recording (seconds)
pause_between = .5;             % Pause duration (seconds) between recordings
fs_target = 250000;            % Sampling rate

save_root = 'D:\_Mic Calibration\20250816\Recordings\1khz\Quarter\';
if ~exist(save_root, 'dir')
    mkdir(save_root);
end

% Create DAQ session
d = daq("ni");
addinput(d, "Dev1", "ai0", "Voltage");
d.Rate = fs_target;

disp('Beginning GRAS mic recordings of 1kHz tone...')

for k = 1:nReps
    fprintf('Recording %d of %d...\n', k, nReps);
    
    % Record
    data = read(d, seconds(duration_s));
    
    % Extract signal and sampling rate
    sig = data.Variables;
    fs = d.Rate;

    % Save
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    filename = sprintf('GRAS_calibration_%s_rep%d.mat', timestamp, k);
    save_path = fullfile(save_root, filename);
    save(save_path, 'sig', 'fs');

    % Plot (optional)
    figure(1); clf;
    plot(data.Time, sig);
    xlabel("Time (s)");
    ylabel("Amplitude (V)");
    title(sprintf('GRAS Recording %d of %d', k, nReps));
    drawnow;

    % Pause between repetitions
    if k < nReps
        pause(pause_between);
    end
end

% Cleanup
clear d;
disp('All recordings complete and saved.');
