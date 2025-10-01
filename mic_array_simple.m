%% Setup (one-time)
deviceID = 'PXI1Slot3';
channelIDs = 0;   % e.g. [0 1 2 3 ...] if more mics
channelLabels = {'Mic1'};
fs = 250000;
recordDuration = 0.050;
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
    fileName = sprintf('mic_%s%s.mat', datestr(now, 'yyyymmdd'), trialStr);
    save(fileName, 'data', 'fs');

    %% Increment
    daqreset;
    trialNum = trialNum + 1;
end
