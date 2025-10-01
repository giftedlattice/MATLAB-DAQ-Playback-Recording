%% Setup (one-time)
deviceID = 'PXI1Slot3';
channelIDs = 0;   % e.g. [0 1 2 3 ...] for multiple mics
channelLabels = {'Mic1'};
fs = 250000;
recordDuration = 0.050; % seconds
triggerSource = 'PFI0';
trialNum = 1;

while true
    %% Setup DAQ for each loop
    d = daq('ni');
    d.Rate = fs;

    for idx = 1:length(channelIDs)
        ch = addinput(d, deviceID, sprintf('ai%d', channelIDs(idx)), 'Voltage');
        ch.TerminalConfig = 'Differential';
        ch.Name = channelLabels{idx};
    end

    % Trigger setup
    addtrigger(d, 'Digital', 'StartTrigger', 'External', [deviceID, '/', triggerSource]);
    d.DigitalTriggers(1).Condition = 'RisingEdge';
    d.NumDigitalTriggersPerRun = 1;
    d.DigitalTriggerTimeout = 300;

    %% Record when triggered
    fprintf('Waiting for trigger on trial %d...\n', trialNum);
    data = read(d, seconds(recordDuration));

    %% Save data
    trialStr = sprintf('_trial%02d', trialNum);
    matName = sprintf('mic_%s%s.mat', datestr(now, 'yyyymmdd'), trialStr);
    save(matName, 'data', 'fs');

    %% Plot and save figure
    numChannels = length(channelLabels);
    rows = ceil(sqrt(numChannels));
    cols = ceil(numChannels / rows);
    timeVec = (0:height(data)-1) / fs;

    figure('Name', sprintf('Trial %d - Recorded Signals', trialNum), ...
           'Position', [100, 100, 300*cols, 250*rows]);

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

    figName = sprintf('micFig_%s%s.png', datestr(now, 'yyyymmdd'), trialStr);
    saveas(gcf, figName);

    %% Clean up and increment
    daqreset;
    trialNum = trialNum + 1;
end
