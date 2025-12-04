function BatPlaybackRecordGUI
% BatPlaybackRecordGUI
% GUI for multi-mic playback & continuous recording with trial management.
%
% Workflow:
%   1. Launch function -> GUI appears.
%   2. Enter BAT ID, select a .wav stimulus.
%   3. Press "Go / Arm + Play":
%        - Creates folder structure: rootSaveDir / YYYYMMDD / BATID /
%        - Determines next trialNum from existing rec_*_trialNN.mat
%        - Arms NI DAQ with external digital start trigger (e.g. PFI0)
%        - Preloads and starts repeating the stimulus output
%        - Waits for external trigger to start acquisition
%   4. At some point, external trigger fires (as in your array code), mics record.
%   5. Press "Stop Recording":
%        - Stops DAQ
%        - Saves recorded data, timestamps, stimulus, and metadata to .mat
%        - (Optional) Plots waveforms + spectrograms
%
% NOTE: This code does NOT add any TTL-to-MIRO logic. If that happens
% elsewhere in your setup, it stays separate.

    %% =========================
    %  User Configuration
    %  =========================
    deviceID           = "PXI1Slot3";        % NI device ID
    channelIDs         = 0;                  % e.g. 0 or [0 1 2 3 4 5 6]
    channelLabels      = {'Mic1'};           % e.g. {'Mic1','Mic2',...}
    fs                 = 250000;             % DAQ sampling rate (Hz)
    triggerSource      = "PFI0";             % external digital trigger line
    rootSaveDir        = 'C:\BatData';       % <=== CHANGE THIS TO YOUR ROOT SAVE DIRECTORY
    defaultAudioDir    = 'C:\Users\jsayles3\Loudspeakers'; % default stimulus dir
    doPlot             = true;               % set false to disable plotting

    % -------------------------
    % Basic checks & mic tag
    % -------------------------
    numChannels = numel(channelIDs);
    if numel(channelLabels) ~= numChannels
        error('Number of channelLabels (%d) must match number of channelIDs (%d).', ...
              numel(channelLabels), numChannels);
    end

    % Build mic tag for filenames
    micIdTag    = "ch"   + strjoin(string(channelIDs), "-");
    cleanLabels = regexprep(channelLabels, '\s+', '');
    micLabelTag = "mics" + strjoin(string(cleanLabels), "-");
    micTag      = micIdTag + "_" + micLabelTag;

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
    d.DigitalTriggers(1).Condition       = "RisingEdge";
    d.NumDigitalTriggersPerRun          = 1;
    d.DigitalTriggerTimeout             = 300;   % seconds (waiting for trigger)

    %% =========================
    %  State variables (shared by nested functions)
    %  =========================
    selectedWavFile   = "";
    batID             = "";
    currentTrialNum   = 1;       % will be updated from existing files
    dataBuffer        = [];      % [N x numChannels]
    timeBuffer        = [];      % [N x 1] TimeStamps
    lhDataAvailable   = [];      % listener handle
    isRunning         = false;
    currentSaveDir    = "";      % full path to DATE/BATID folder
    currentMeta       = struct();% metadata struct
    currentSignal     = [];      % playback signal actually sent

    %% =========================
    %  Build GUI
    %  =========================
    fig = uifigure('Name','Bat Playback & Recording','Position',[100 100 600 260]);

    % BAT ID
    uilabel(fig, 'Position',[20 210 80 20], 'Text','BAT ID:');
    txtBatID = uieditfield(fig, 'text', 'Position',[100 210 150 22]);

    % WAV file selection
    uilabel(fig, 'Position',[20 170 80 20], 'Text','Stimulus (.wav):');
    txtWav = uieditfield(fig, 'text', 'Position',[100 170 350 22], ...
                         'Editable','off', 'Value','<no file selected>');
    btnSelectWav = uibutton(fig, 'push', ...
                            'Position',[470 170 100 24], ...
                            'Text','Browse...', ...
                            'ButtonPushedFcn',@onSelectWav);

    % Status area
    lblStatus = uilabel(fig, 'Position',[20 130 550 22], ...
                        'Text','Status: Idle', ...
                        'FontWeight','bold');

    % Go / Arm + Play button
    btnStart = uibutton(fig, 'push', ...
                        'Position',[100 70 150 40], ...
                        'Text','Go / Arm + Play', ...
                        'FontWeight','bold', ...
                        'ButtonPushedFcn',@onStartTrial);

    % Stop button
    btnStop = uibutton(fig, 'push', ...
                       'Position',[300 70 150 40], ...
                       'Text','Stop Recording', ...
                       'FontWeight','bold', ...
                       'Enable','off', ...
                       'ButtonPushedFcn',@onStopTrial);

    % When figure closes, ensure DAQ is stopped/cleaned
    fig.CloseRequestFcn = @onClose;

    %% =========================
    %  Nested callbacks
    %  =========================

    function onSelectWav(~,~)
        % Let user pick a .wav file
        [fName, fPath] = uigetfile({'*.wav','WAV files (*.wav)'}, ...
                                   'Select stimulus WAV file', defaultAudioDir);
        if isequal(fName,0)
            return;
        end
        selectedWavFile = string(fullfile(fPath, fName));
        txtWav.Value    = char(selectedWavFile);
        lblStatus.Text  = sprintf('Status: Selected %s', fName);
    end

    function onStartTrial(~,~)
        if isRunning
            return;
        end

        % Get BAT ID
        batID = strtrim(txtBatID.Value);
        if isempty(batID)
            uialert(fig, 'Please enter a BAT ID before starting.', 'Missing BAT ID');
            return;
        end

        if selectedWavFile == ""
            uialert(fig, 'Please select a .wav file before starting.', 'No WAV Selected');
            return;
        end

        % Create/locate save directory: rootSaveDir / yyyymmdd / BATID /
        dateStr   = datestr(datetime('today'), 'yyyymmdd');
        currentSaveDir = fullfile(rootSaveDir, dateStr, batID);
        if ~exist(currentSaveDir, 'dir')
            mkdir(currentSaveDir);
        end

        % Determine next trial number from existing rec_*.mat files
        currentTrialNum = determineNextTrialNum(currentSaveDir);

        % Load and prepare audio signal from WAV
        [signal, origFs] = audioread(selectedWavFile);
        if size(signal,2) > 1
            signal = signal(:,1);  % use first channel if stereo
        end
        signal = signal(:);        % column

        origNumSamples = numel(signal);
        origDuration   = origNumSamples / origFs;   % seconds

        % Resample to match DAQ rate if needed
        if origFs ~= fs
            signal = resample(signal, fs, origFs);
        end

        % Normalize to avoid clipping on AO
        maxVal = max(abs(signal));
        if maxVal > 0
            signal = signal / maxVal;
        end

        % We'll repeat the signal in hardware until Stop is pressed.
        % (Using repeatoutput; acquisition starts on external trigger.)
        currentSignal = signal;

        % Prepare metadata (trial info; some fields filled after acquisition)
        currentMeta = struct();
        currentMeta.deviceID        = char(deviceID);
        currentMeta.channelIDs      = channelIDs;
        currentMeta.channelLabels   = channelLabels;
        currentMeta.fs              = fs;
        currentMeta.triggerSource   = char(triggerSource);

        currentMeta.audioFile               = char(selectedWavFile);
        currentMeta.audioVarName            = 'wavFile'; % not from .mat, but path
        currentMeta.audioFsOriginal         = origFs;
        currentMeta.audioDurationOriginal   = origDuration;
        currentMeta.audioFsPlayback         = fs;
        % playbackDuration will be determined by actual acquisition length
        currentMeta.trialNum        = currentTrialNum;
        currentMeta.trialStartTime  = datetime("now");
        currentMeta.micTag          = char(micTag);
        currentMeta.BATID           = batID;
        currentMeta.dateStr         = dateStr;

        % Reset buffers
        dataBuffer = [];
        timeBuffer = [];

        % Add DataAvailable listener
        if ~isempty(lhDataAvailable) && isvalid(lhDataAvailable)
            delete(lhDataAvailable);
        end
        lhDataAvailable = addlistener(d, "DataAvailable", @onDataAvailable);

        % Queue output signal and start continuous + repeatoutput
        preload(d, currentSignal);
        lblStatus.Text = sprintf('Status: Armed. Waiting for external trigger (trial %d)...', currentTrialNum);

        % Start DAQ: input + repeatoutput; acquisition actually begins on trigger
        try
            start(d, "repeatoutput");
        catch ME
            uialert(fig, sprintf('Error starting DAQ:\n%s', ME.message), 'DAQ Error');
            lblStatus.Text = 'Status: Error starting DAQ';
            return;
        end

        isRunning    = true;
        btnStart.Enable = 'off';
        btnStop.Enable  = 'on';
    end

    function onStopTrial(~,~)
        if ~isRunning
            return;
        end

        % Stop DAQ
        try
            stop(d);
        catch
            % ignore stop errors
        end

        isRunning = false;

        % Remove listener
        if ~isempty(lhDataAvailable) && isvalid(lhDataAvailable)
            delete(lhDataAvailable);
            lhDataAvailable = [];
        end

        % If nothing recorded (no trigger), just report
        if isempty(dataBuffer)
            lblStatus.Text = sprintf('Status: No data recorded for trial %d (no trigger?).', currentTrialNum);
            btnStart.Enable = 'on';
            btnStop.Enable  = 'off';
            return;
        end

        % Build timetable for recorded data
        % timeBuffer is relative to trigger; convert to seconds
        tVec = timeBuffer;  % already seconds from DataAvailable

        % Create timetable with appropriate channel names
        data = array2timetable(dataBuffer, ...
            "RowTimes", seconds(tVec), ...
            "VariableNames", channelLabels);

        % Compute playbackDuration/recordDuration from actual data
        totalDuration = tVec(end) - tVec(1);
        currentMeta.audioDurationPlayback = totalDuration;
        currentMeta.recordDuration        = totalDuration;

        % File naming: rec_<micTag>_<date>_BATID_trialNN.mat
        trialStr  = sprintf('trial%02d', currentTrialNum);
        matFile   = sprintf('rec_%s_%s_%s_%s.mat', currentMeta.micTag, ...
                            currentMeta.dateStr, currentMeta.BATID, trialStr);
        matPath   = fullfile(currentSaveDir, matFile);

        % Save MAT file: data, timestamps, playback signal, metadata
        timestamps = tVec;   %#ok<NASGU>  (for compatibility)
        signal     = currentSignal; %#ok<NASGU>
        meta       = currentMeta;   %#ok<NASGU>

        save(matPath, 'data', 'timestamps', 'signal', 'meta', '-v7.3');

        % Optional plotting (similar to original code)
        if doPlot
            rowsGrid = ceil(sqrt(numChannels));
            colsGrid = ceil(numChannels / rowsGrid);

            figPlot = figure('Name', sprintf('Recorded Signals - Trial %d', currentTrialNum), ...
                             'Position', [100, 100, 300*colsGrid, 250*rowsGrid*2]);

            timeVec = tVec - tVec(1);  % start at 0

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

            pngFile = sprintf('rec_%s_%s_%s_%s.png', currentMeta.micTag, ...
                              currentMeta.dateStr, currentMeta.BATID, trialStr);
            pngPath = fullfile(currentSaveDir, pngFile);
            saveas(figPlot, pngPath);
            % close(figPlot); % uncomment if you don't want windows piling up
        end

        lblStatus.Text = sprintf('Status: Saved %s. Ready for next trial.', matFile);

        % Prepare for next trial (same batID, same WAV by default)
        currentTrialNum = currentTrialNum + 1;

        btnStart.Enable = 'on';
        btnStop.Enable  = 'off';
    end

    function onDataAvailable(~, event)
        % Append incoming data and timestamps to buffers
        dataBuffer = [dataBuffer; event.Data];             %#ok<AGROW>
        timeBuffer = [timeBuffer; event.TimeStamps];       %#ok<AGROW>
    end

    function onClose(~,~)
        % Clean-up on figure close
        try
            if isRunning
                stop(d);
            end
        catch
        end

        if ~isempty(lhDataAvailable) && isvalid(lhDataAvailable)
            delete(lhDataAvailable);
        end

        try
            daqreset;
        catch
        end

        delete(fig);
    end
end

% =========================
%  Helper: trial numbering
% =========================
function nextTrial = determineNextTrialNum(saveDir)
    % Looks for rec_*_trialNN.mat in saveDir and returns NN+1
    files = dir(fullfile(saveDir, 'rec_*_trial*.mat'));
    if isempty(files)
        nextTrial = 1;
        return;
    end

    trialNums = [];
    for k = 1:numel(files)
        tok = regexp(files(k).name, 'trial(\d+)\.mat$', 'tokens', 'once');
        if ~isempty(tok)
            n = str2double(tok{1});
            if ~isnan(n)
                trialNums(end+1) = n; %#ok<AGROW>
            end
        end
    end

    if isempty(trialNums)
        nextTrial = 1;
    else
        nextTrial = max(trialNums) + 1;
    end
end
