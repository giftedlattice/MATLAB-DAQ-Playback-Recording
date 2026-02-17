function convertCineFolder()

% Recursively finds all .cine/.cin files
% Opens a folder selection dialog
% Mirrors folder structure into a new folder called "converted"
% Saves each frame as individual image files
%
% Requires cineInfo.m and cineRead2.m in MATLAB path

%% Select root folder via popup
rootFolder = uigetdir(pwd, 'Select Root Folder Containing CINE Files');

if rootFolder == 0
    disp('No folder selected. Exiting.');
    return
end

fprintf('Selected folder:\n%s\n', rootFolder);

%% Create converted root folder
convertedRoot = fullfile(rootFolder, 'converted');
if ~exist(convertedRoot, 'dir')
    mkdir(convertedRoot);
end

%% Find all cine files recursively
cineFiles = [ ...
    dir(fullfile(rootFolder, '**', '*.cine')); ...
    dir(fullfile(rootFolder, '**', '*.cin')) ...
    ];

fprintf('Found %d cine files\n', length(cineFiles));

%% Process each file
for k = 1:length(cineFiles)

    inputFile = fullfile(cineFiles(k).folder, cineFiles(k).name);

    % Skip files already inside "converted"
    if contains(cineFiles(k).folder, filesep + "converted")
        continue
    end

    fprintf('\nProcessing: %s\n', inputFile);

    try
        info = cineInfo(inputFile);
    catch
        warning('Could not read header for %s', inputFile);
        continue
    end

    % Build mirrored output path
    relativePath = strrep(cineFiles(k).folder, rootFolder, '');
    outputFolder = fullfile(convertedRoot, relativePath);

    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    % Create subfolder per cine file
    [~, baseName, ~] = fileparts(cineFiles(k).name);
    cineOutputFolder = fullfile(outputFolder, baseName);

    if ~exist(cineOutputFolder, 'dir')
        mkdir(cineOutputFolder);
    end

    fprintf('Exporting %d frames...\n', info.NumFrames);

    for frameNum = 1:info.NumFrames

        try
            frame = cineRead2(inputFile, frameNum);
        catch
            warning('Error reading frame %d of %s', frameNum, inputFile);
            continue
        end

        % Save based on bit depth
        if isa(frame, 'uint16')
            imwrite(frame, fullfile(cineOutputFolder, ...
                sprintf('%s_%05d.tif', baseName, frameNum)));
        elseif isa(frame, 'uint8')
            imwrite(frame, fullfile(cineOutputFolder, ...
                sprintf('%s_%05d.png', baseName, frameNum)));
        else
            imwrite(mat2gray(frame), fullfile(cineOutputFolder, ...
                sprintf('%s_%05d.png', baseName, frameNum)));
        end

        if mod(frameNum,100) == 0
            fprintf('  Frame %d / %d\n', frameNum, info.NumFrames);
        end
    end

    fprintf('Finished %s\n', baseName);
end

fprintf('\nAll conversions complete.\n');

end