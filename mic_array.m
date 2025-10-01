
%% Setup (one-time)
deviceID = 'PXI1Slot3';
channelIDs = 0;
channelLabels = {'Mic1'};
%channelLabels = {'Mic1','Mic2','Mic3','Mic4','Mic5','Mic6','Mic7'};
fs = 250000;
recordDuration = 0.050;
triggerSource = 'PFI0';
audioDir = 'C:\Users\jsayles3\Loudspeakers';
selectSpecificFile = false;
Current_Mic = "1";
trialNum = 1;

while true
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
    signal = signal(:); % column

    if isfield(dataStruct, 'Fs')
        audioFs = dataStruct.Fs;
    else
        audioFs = fs;
    end

    if audioFs ~= fs
        signal = resample(signal, fs, audioFs);
    end

    signalLength = round(recordDuration * fs);
    if length(signal) > signalLength
        signal = signal(1:signalLength);
    else
        signal = [signal; zeros(signalLength - length(signal), 1)];
    end

    signal = signal / max(abs(signal));

    %% Setup DAQ for each loop
    d = daq('ni');
    d.Rate = fs;

    for idx = 1:length(channelIDs)
        ch = addinput(d, deviceID, sprintf('ai%d', channelIDs(idx)), 'Voltage');
        ch.TerminalConfig = 'Differential';
        ch.Name = channelLabels{idx};
    end

    addoutput(d, deviceID, 'ao0', 'Voltage');

    addtrigger(d, 'Digital', 'StartTrigger', 'External', [deviceID, '/', triggerSource]);
    d.DigitalTriggers(1).Condition = 'RisingEdge';
    d.NumDigitalTriggersPerRun = 1;
    d.DigitalTriggerTimeout = 300;

    %% Read and Write Simultaneously
    fprintf('Waiting for trigger on trial %d...\n', trialNum);
    [data, timestamps] = readwrite(d, signal);

    %% Save and Plot
    trialStr = sprintf('_trial%02d', trialNum);
    fileName = ["mic_", datestr(now, 'yyyymmdd'), trialStr, '.mat'];
    save(fileName, 'data', 'fs');

numChannels = length(channelLabels);
rows = ceil(sqrt(numChannels));
cols = ceil(numChannels / rows);

figure('Name', 'Recorded Signals', 'Position', [100, 100, 300*cols, 250*rows]);
timeVec = (0:height(data)-1) / fs;

for idx = 1:numChannels
    subplot(rows*2, cols, idx);  % Top half: time series
    plot(timeVec, data{:, idx});
    title(sprintf('%s - Time', channelLabels{idx}));
    xlabel('Time (s)');
    ylabel('Amplitude (V)');

    subplot(rows*2, cols, idx + numChannels);  % Bottom half: spectrogram
    spectrogram(data{:, idx}, 256, 200, 512, fs, 'yaxis');
    title(sprintf('%s - Spectrogram', channelLabels{idx}));
end



    saveas(gcf, [Current_Mic, datestr(now, 'yyyymmdd'), trialStr, '.png']);
%     close(gcf);

    %% Clean up and increment
    daqreset;
    trialNum = trialNum + 1;
end

% trial number convention needs to be amended to refer to angle to the
% speaker. Starting at ??What?? degree and moving by 10's. We will start at
% 0 and move clock wise to 350.
% Bonus is to instead of running on trigger to run "angle" ever X seconds
% for automation/
%Test new naming convention for Mic Number
%Meta Data as a pop up for distance, and amp setting, temp, humidity, Mic
%type, speaker type, 
%set trigger to auto do the 5 trilas for each degree needed, and can be one
%after the other just need it to be 5 recordings

