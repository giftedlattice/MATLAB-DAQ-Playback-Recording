%% ============================================
%  Multi-mic Triggered Playback & Recording
%  ============================================
clc; clear; close all;

%% =========================
%  User Configuration
%  =========================
deviceID          = "PXI1Slot3";          % NI device ID

% --- USER CONTROLS HOW MANY MICS HERE ---
channelIDs        = 0;                    % e.g. 0 or [0 1 2 3 4 5 6]
channelLabels     = {'Mic1'};             % e.g. {'Mic1','Mic2',...}
% channelIDs    = 0:6;
% channelLabels = {'Mic1','Mic2','Mic3','Mic4','Mic5','Mic6','Mic7'};

fs                = 250000;               % DAQ sampling rate (Hz)
recordDuration    = 0.050;                % seconds
triggerSource     = "PFI0";               % external digital trigger line
audioDir          = 'C:\Users\jsayles3\Loudspeakers'; % dir of .mat file with audio data
selectSpecificFile = false;               % false = random file each trial
doPlot            = true;                 % set false to disable plotting
trialNum          = 1;                    % starting trial index

%% =========================
%  Basic checks & mic tag
%  =========================
numChannels = numel(channelIDs);
if numel(channelLabels) ~= numChannels
    error('Number of channelLabels (%d) must match number of channelIDs (%d).', ...
          numel(channelLabels), numChannels);
end

% Build mic tag for filenames
% Example: channelIDs = [0 1 2]  -> micIdTag = "ch0-1-2"
micIdTag = "ch" + strjoin(string(channelIDs), "-");

% Example: channelLabels = {'Mic1','Rear Mic'} -> "micsMic1-RearMic"
cleanLabels = regexprep(channelLabels, '\s+', '');   % remove spaces
micLabelTag = "mics" + strjoin(string(cleanLabels), "-");

% Combined tag: "ch0-1-2_micsMic1-Mic2-Mic3"
micTag = micIdTag + "_" + micLabelTag;

%% =========================
%  Pre-list audio files
%  =========================
audioFiles = dir(fullfile(audioDir, '*.mat'));
if isempty(audioFiles)
    error('No .mat audio files found in %s', audioDir);
end

%% =========================
%  DAQ Setup (one-time)
%  =========================
d = daq("ni");
d.Rate = fs;

% Add input channels for each mic
for idx = 1:numChannels
    ch = addinput(d, deviceID, sprintf('ai%d', channelIDs(idx)), "Voltage");
    ch.TerminalConfig = "Differential";
    ch.Name = channelLabels{idx};
end

% Single analog output channel for playback
addoutput(d, deviceID, "ao0", "Voltage");

% External digital start trigger
addtrigger(d, "Digital", "StartTrigger", "External", deviceID + "/" + triggerSource);
d.DigitalTriggers(1).Condition = "RisingEdge";
d.NumDigitalTriggersPerRun    = 1;
d.DigitalTriggerTimeout       = 300;   % seconds

%% =========================
%  Acquisition Loop
%  =========================
while true

    %% ---- Select audio file for this trial ----
    if selectSpecificFile
        [fileNameA, filePathA] = uigetfile(fullfile(audioDir, '*.mat'), ...
                                           'Select an audio file');
        if isequal(fileNameA, 0)
            warning('No file selected. Stopping acquisition loop.');
            break;
        end
        selectedFile = fullfile(filePathA, fileNameA);
    else
        % Randomly pick an audio file from the pre-listed directory
        idxFile      = randi(numel(audioFiles));
        selectedFile = fullfile(audioDir, audioFiles(idxFile).name);
    end

    fprintf('\n=== Trial %d ===\n', trialNum);
    fprintf('Using audio file: %s\n', selectedFile);

    %% ---- Load and select audio signal safely ----
    dataStruct = load(selectedFile);
    varNames   = fieldnames(dataStruct);

    % Try common audio variable names first
    preferredNames = {'signal','audio','y','x'};
    signal = [];
    signalName = '';

    for k = 1:numel(preferredNames)
        if isfield(dataStruct, preferredNames{k})
            candidate = dataStruct.(preferredNames{k});
            if isnumeric(candidate) && isvector(candidate)
                signal = candidate;
                signalName = preferredNames{k};
                break;
            end
        end
    end

    % If none of the preferred names are found, choose a reasonable fallback
    if isempty(signal)
        for k = 1:numel(varNames)
            if strcmpi(varNames{k}, 'Fs')
                continue; % skip sample-rate-only fields
            end
            candidate = dataStruct.(varNames{k});
            if isnumeric(candidate) && isvector(candidate) && numel(candidate) > 10
                signal = candidate;
                signalName = varNames{k};
                break;
            end
        end
    end

    if isempty(signal)
        error('Could not find a suitable audio signal in %s.', selectedFile);
    end

    signal = signal(:);   % ensure column vector

    % --- Original audio metadata ---
    origNumSamples = numel(signal);

    if isfield(dataStruct, 'Fs')
        origFs = dataStruct.Fs;        % original file sample rate
    else
        origFs = fs;                   % assume DAQ rate if not stored
    end

    origDuration = origNumSamples / origFs;   % seconds, original audio length

    % --- Resample to match DAQ rate if needed ---
    if origFs ~= fs
        signal = resample(signal, fs, origFs);
    end

    % --- Enforce desired record duration for playback/recording ---
    signalLength = round(recordDuration * fs);
    if numel(signal) > signalLength
        signal = signal(1:signalLength);
    else
        signal = [signal; zeros(signalLength - numel(signal), 1)];
    end

    % Normalize to avoid clipping on AO
    maxVal = max(abs(signal));
    if maxVal > 0
        signal = signal / maxVal;
    end

    % Playback metadata (what we actually send to AO/DAQ)
    playbackNumSamples = numel(signal);
    playbackDuration   = playbackNumSamples / fs;   % should ? recordDuration

    %% ---- Read and Write Simultaneously ----
    fprintf('Waiting for trigger on %s (trial %d)...\n', char(triggerSource), trialNum);
    trialStartTime = datetime("now");
    [data, timestamps] = readwrite(d, signal);

    %% ---- Prepare metadata ----
    meta = struct();
    meta.deviceID        = char(deviceID);
    meta.channelIDs      = channelIDs;
    meta.channelLabels   = channelLabels;
    meta.fs              = fs;                     % DAQ rate (playback/record)
    meta.recordDuration  = recordDuration;         % requested duration (s)
    meta.triggerSource   = char(triggerSource);

    % Audio file info
    meta.audioFile               = selectedFile;
    meta.audioVarName            = signalName;         % which variable was used
    meta.audioFsOriginal         = origFs;            % original file Fs
    meta.audioDurationOriginal   = origDuration;      % original file duration (s)
    meta.audioFsPlayback         = fs;                % playback Fs (same as meta.fs)
    meta.audioDurationPlayback   = playbackDuration;  % actual used duration (s)

    % Trial info
    meta.trialNum        = trialNum;
    meta.trialStartTime  = trialStartTime;
    meta.micTag          = char(micTag);

    %% ---- Save data ----
    trialStr = sprintf('_trial%02d', trialNum);
    dateStr  = datestr(now, 'yyyymmdd');

    matFile = sprintf('rec_%s_%s%s.mat', meta.micTag, dateStr, trialStr);
    fprintf('Saving MAT file: %s\n', matFile);

    % Save data (timetable), timestamps, playback signal, and metadata
    save(matFile, 'data', 'timestamps', 'signal', 'meta', '-v7.3');

    %% ---- Optional plotting ----
    if doPlot
        rowsGrid = ceil(sqrt(numChannels));
        colsGrid = ceil(numChannels / rowsGrid);

        figure('Name', sprintf('Recorded Signals - Trial %d', trialNum), ...
               'Position', [100, 100, 300*colsGrid, 250*rowsGrid*2]);

        % Simple time vector based on fs
        timeVec = (0:height(data)-1) / fs;

        for idx = 1:numChannels
            % Top half: time series
            subplot(rowsGrid*2, colsGrid, idx);
            plot(timeVec, data{:, idx});
            title(sprintf('%s - Time', channelLabels{idx}), 'Interpreter', 'none');
            xlabel('Time (s)');
            ylabel('Amplitude (V)');

            % Bottom half: spectrogram
            subplot(rowsGrid*2, colsGrid, idx + numChannels);
            spectrogram(data{:, idx}, 256, 200, 512, fs, 'yaxis');
            title(sprintf('%s - Spectrogram', channelLabels{idx}), 'Interpreter', 'none');
        end

        pngFile = sprintf('rec_%s_%s%s.png', meta.micTag, dateStr, trialStr);
        fprintf('Saving PNG file: %s\n', pngFile);
        saveas(gcf, pngFile);
        % close(gcf);   % uncomment if you don't want windows piling up
    end

    %% ---- Increment trial counter ----
    trialNum = trialNum + 1;
end

%% Optional final cleanup
daqreset;
fprintf('Acquisition loop ended. DAQ reset.\n');
