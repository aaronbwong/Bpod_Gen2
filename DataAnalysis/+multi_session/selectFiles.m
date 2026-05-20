function selectedFiles = selectFiles(defaultDataPath)
%selectFiles Prompt to select .mat session files or folders.
%   selectedFiles = multi_session.selectFiles(defaultDataPath)
%   prompts the user to choose individual .mat files or a folder
%   containing .mat files. It returns a cell array of absolute file paths.

if nargin < 1 || isempty(defaultDataPath)
    defaultDataPath = pwd;
end
if ~exist(defaultDataPath, 'dir')
    warning('Default path does not exist: %s. Using current directory instead.', defaultDataPath);
    defaultDataPath = pwd;
end

selectedFiles = {};
currentPath = defaultDataPath;
fileCount = 0;

fprintf('=== File Selection ===\n');
fprintf('You can select multiple files at once (hold Ctrl/Cmd to select multiple)\n');

while true
    selectionType = questdlg('Choose selection type', 'Select Files or Folder', 'Files', 'Folder', 'Files');
    if isempty(selectionType)
        selectionType = 'Files';
    end

    switch selectionType
        case 'Files'
            [filename, filepath, ~] = uigetfile('*.mat', ...
                sprintf('Select file(s) (Cancel to finish) - Currently %d file(s) selected', fileCount), ...
                currentPath, ...
                'MultiSelect', 'on');
            if isequal(filename, 0) || isequal(filepath, 0)
                break;
            end

            if ischar(filename)
                filenames = {filename};
            else
                filenames = filename;
            end

            newFiles = fullfile(filepath, filenames(:));
            selectedFiles = [selectedFiles; newFiles]; %#ok<AGROW>
            numSelected = numel(newFiles);
            fileCount = fileCount + numSelected;
            for k = 1:numSelected
                fprintf('File %d: %s\n', fileCount - numSelected + k, newFiles{k});
            end
            currentPath = filepath;

        case 'Folder'
            folderpath = uigetdir(currentPath, sprintf('Select folder (Cancel to finish) - Currently %d file(s) selected', fileCount));
            if isequal(folderpath, 0)
                break;
            end
            folderFiles = multi_session.selectFilesFromFolder(folderpath);
            if isempty(folderFiles)
                fprintf('No .mat files found in folder: %s\n', folderpath);
                numSelected = 0;
            else
                selectedFiles = [selectedFiles; folderFiles(:)]; %#ok<AGROW>
                numSelected = numel(folderFiles);
                fileCount = fileCount + numSelected;
                for k = 1:numSelected
                    fprintf('File %d: %s\n', fileCount - numSelected + k, folderFiles{k});
                end
            end
                currentPath = folderpath;
    end

    if fileCount == 0
        choice = questdlg('No files selected yet. Do you want to continue selecting?', 'File Selection', 'Yes', 'No', 'Yes');
    else
        choice = questdlg(sprintf('%d files selected (total: %d)\n\nDo you want to select more files?', numSelected, fileCount), ...
            'File Selection', 'Yes', 'No', 'Yes');
    end
    if strcmp(choice, 'No')
        break;
    end
end

selectedFiles = unique(selectedFiles, 'stable');
if isempty(selectedFiles)
    fprintf('No files selected.\n');
else
    fprintf('\nFinished selecting files. Total: %d file(s)\n\n', numel(selectedFiles));
end
end
