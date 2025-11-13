% Convert TDMS data to MAT files inplace (Shivam C.)
% Modified from 2014/09/26 Script (from Xiaoyan Y.)
% Modified on 20250120 by Jake to handle errors and continue rather than
% stop

% Get data directory
DATA_DIR = uigetdir('C:\Users\jsayles3\Desktop\_Mic Calibration\20250816\Recordings\Polarity\');

% Ensure a directory is selected
if DATA_DIR == 0
    disp('No directory selected. Exiting...');
    return;
end

% Save modified files inplace
SAVE_DIR = DATA_DIR;

% Get number of files
files = dir(fullfile(DATA_DIR, '*.tdms'));

% Specify sampling rate
fs = 250e3;

% Add the folder containing 'convertTDMS' to the MATLAB path
addpath('Z:\Jake\Code4Labview\Jinhong'); % Update the path as needed

% GUI to confirm number of files and sampling rate
fig = uifigure();
selection = uiconfirm(fig, ...
    "Number of files: " + string(size(files, 1)) + "; fs: " + string(fs) + " Hz", ...
    'Confirmation');

% Proceed based on user input
switch selection
    case 'OK'
        for iF = 1:length(files)
            try
                % Run through files and convert
                fprintf('Processing file %d/%d: %s\n', iF, length(files), files(iF).name);

%                 % Convert TDMS to MATLAB format
%                 [ConvertedData, ConvertVer, ChanNames, GroupNames, ci] = ...
%                     convertTDMS(0, fullfile(DATA_DIR, files(iF).name));
[ConvertedData, ConvertVer, ChanNames, GroupNames, ci] = ...
    convertTDMS(false, fullfile(DATA_DIR, files(iF).name));  % 'false' skips DAQmxRaw errors

                % Extract signal data
                sig = [ConvertedData.Data.MeasuredData(:).Data];
                sig = sig - repmat(mean(sig, 1), size(sig, 1), 1); % Center data (remove DC offset)
                sig = sig(:, 1); % Keep only the first channel

                % Generate output filename
                S = strsplit(files(iF).name, '_nodaqmx');
                outputFilename = fullfile(SAVE_DIR, [S{1}, '_mic_data.mat']);

                % Save to MAT file
                save(outputFilename, 'sig', 'fs');

                % Log success
                fprintf('Successfully processed: %s\n', files(iF).name);

            catch ME
                % Log the error and continue with the next file
                fprintf('Error processing file %s: %s\n', files(iF).name, ME.message);
                continue; % Skip to the next file
            end
        end
    case 'Cancel'
        disp('Operation cancelled by the user.');
        return;
end

disp('Batch processing completed.');
