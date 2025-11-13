%% wants
% Way to say stop in the code and have it stop, or similar

% Need to be able to take the file and make it x ms long and repeat y times
% with z time in between




%% Setup (one-time)
% deviceID = 'PXI1Slot3';
deviceID = 'Dev1';
channelIDs = 2;
channelLabels = {'Mic1'};
fs = 250000;               % Sample rate in Hz
recordDuration = 0.150;    % Duration of each recording in seconds
triggerSource = 'PFI0';
audioDir = 'Z:\Jake\_Mic Calibration\Pipeline\Call';
% audioDir = 'C:\Users\jsayles3\Loudspeakers';
%audioDir = 'C:\Users\jsayl\OneDrive\Documents\MATLAB';
Current_Mic = "SFR-M7_";
selectSpecificFile = false;

% User-defined pause between recordings (in seconds)
pauseBetweenRecordings = 0.5;

angleStep = 10;              % 10-degree increments
totalAngles = 360;


% === SELECT AUDIO FILE ===
[callFile, callPath] = uigetfile('*.mat', 'Select a MAT file containing your sound (e.g., call1)');
if isequal(callFile, 0)
    error('No file selected. Exiting...');
end

% === LOAD CALL ===
callData = load(fullfile(callPath, callFile));
fieldNames = fieldnames(callData);
call1 = callData.(fieldNames{1});  % Assumes first variable is the signal
call1 = call1(:);                  % Ensure column vector

% === NORMALIZE SIGNAL TO DESIRED AMPLITUDE ===
call1 = call1 ./ rms(call1) * 1; %ampl_pulse;

% === CLIP TO DAC LIMITS (optional, based on output hardware) ===
call1(call1 > 9.99) = 9.99;
call1(call1 < -9.99) = -9.99;




numRepeats = 5;      % x: number of times to repeat the signal
callDurationMs = length(call1) / fs * 1000;

gapDurationMs = 50;  % z: gap between calls in milliseconds



% Prompt user to select save directory
saveDir = uigetdir(pwd, 'Select directory to save output files');
if saveDir == 0
    error('No directory selected. Exiting.');
end

% Ask user for starting angle
startFrom = input('Start from angle (0–350): ');
if isempty(startFrom) || ~isnumeric(startFrom)
    error('Invalid starting angle.');
end

angleSequence = mod(startFrom:angleStep:(startFrom + totalAngles - angleStep), 360);

%% Main Loop
for startAngle = angleSequence
    for subTrial = 1:1
        angle = mod(startAngle, totalAngles);  % All 5 recordings are at this angle

        % Pause between subtrials (except the first)
        if subTrial > 1
            fprintf('Waiting %.2f seconds before next recording...\n', pauseBetweenRecordings);
            pause(pauseBetweenRecordings);
        end

        %% Prepare sound
        audioFiles = dir(fullfile(audioDir, '*.mat'));
        if selectSpecificFile
            [fileNameA, filePathA] = uigetfile(fullfile(audioDir, '*.mat'), 'Select an audio file');
            if isequal(fileNameA, 0), error('No file selected. Exiting.'); end
            selectedFile = fullfile(filePathA, fileNameA);
        else
            selectedFile = fullfile(audioDir, audioFiles(randi(numel(audioFiles))).name);
        end

        dataStruct = load(selectedFile);
        varNames = fieldnames(dataStruct);
        signal = dataStruct.(varNames{1});
        signal = signal(:);  % ensure column vector
        if isfield(dataStruct, 'Fs')
            audioFs = dataStruct.Fs;
        else
            audioFs = fs;
        end

        if audioFs ~= fs
            signal = resample(signal, fs, audioFs);
        end



        % --- New: Signal Manipulation ---
        callSamples = round(callDurationMs / 1000 * fs);
        gapSamples  = round(gapDurationMs / 1000 * fs);

        % Truncate or pad the original signal to match the desired call length
        if length(signal) > callSamples
            signal = signal(1:callSamples);
        else
            signal = [signal; zeros(callSamples - length(signal), 1)];
        end

        % Generate one gap
        gap = zeros(gapSamples, 1);

        % Construct full playback sequence
        signal = repmat([signal; gap], numRepeats, 1);

%         % Remove final gap
%         signal = signal(1:end - gapSamples);

        % Normalize final signal
        signal = signal / max(abs(signal));


        %% Setup DAQ
        d = daq('ni');
        d.Rate = fs;

        for idx = 1:length(channelIDs)
            ch = addinput(d, deviceID, sprintf('ai%d', channelIDs(idx)), 'Voltage');
            ch.TerminalConfig = 'Differential';
            ch.Name = channelLabels{idx};
        end

        addoutput(d, deviceID, 'ao0', 'Voltage');

        % Trigger logic
        if subTrial == 1
            addtrigger(d, 'Digital', 'StartTrigger', 'External', [deviceID, '/', triggerSource]);
            d.DigitalTriggers(1).Condition = 'RisingEdge';
            d.NumDigitalTriggersPerRun = 1;
            d.DigitalTriggerTimeout = 300;

            fprintf('Waiting for trigger at angle %d°, subtrial %d...\n', angle, subTrial);
            [data, timestamps] = readwrite(d, signal);
        else
            fprintf('Auto-recording at angle %d°, subtrial %d...\n', angle, subTrial);
            [data, timestamps] = readwrite(d, signal);  % No trigger
        end

        %% Save and Plot
        trialStr = sprintf('_%03d_%d', angle, subTrial);
        filenameMat = fullfile(saveDir, [char(Current_Mic), datestr(now, 'yyyymmdd'), trialStr, '.mat']);
        sig = data{:,1};  
        save(filenameMat, 'sig', 'fs', 'angle');

        numChannels = length(channelLabels);
        rows = ceil(sqrt(numChannels));
        cols = ceil(numChannels / rows);

        figure('Name', 'Recorded Signals', 'Position', [100, 100, 300*cols, 250*rows]);
        timeVec = (0:height(data)-1) / fs;

        for idx = 1:numChannels
            subplot(rows*2, cols, idx);
            plot(timeVec, data{:, idx});
            title(sprintf('%s - Time', channelLabels{idx}));
            xlabel('Time (s)');
            ylabel('Amplitude (V)');

            subplot(rows*2, cols, idx + numChannels);
            spectrogram(data{:, idx}, 256, 200, 512, fs, 'yaxis');
            title(sprintf('%s - Spectrogram', channelLabels{idx}));
        end

        filenamePng = fullfile(saveDir, [char(Current_Mic), datestr(now, 'yyyymmdd'), trialStr, '.png']);
        saveas(gcf, filenamePng);
        close(gcf);

        %% Cleanup
        daqreset;
    end
end
