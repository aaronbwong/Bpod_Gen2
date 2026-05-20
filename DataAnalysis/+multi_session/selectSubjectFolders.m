function selectedFiles = selectSubjectFolders(rootFolder, fileNameFormat)
%selectSubjectFolders Select all .mat files under chosen subject folders.
%   selectedFiles = multi_session.selectSubjectFolders(rootFolder, fileNameFormat)
%   scans the immediate subfolders of rootFolder, prompts the user to
%   select one or more subject folders, and returns all matching .mat
%   session files inside the selected subject folders.

if nargin < 1 || isempty(rootFolder)
    rootFolder = pwd;
end
if ~exist(rootFolder, 'dir')
    error('Folder does not exist: %s', rootFolder);
end
if nargin < 2 || isempty(fileNameFormat)
    fileNameFormat = '(?<mouse>[^_]+)_(?<protocol>[^_]+)_(?<datetime>[\d]{8}_[\d]{6}).mat';
end

listing = dir(rootFolder);
foldersToExclude = {'.', '..','CustomPlotFig','SessionSettingCollection'};
subfolders = {listing([listing.isdir] & ~ismember({listing.name}, foldersToExclude)).name};
if isempty(subfolders)
    selectedFiles = {};
    return;
end

[selectedIdx, ok] = listdlg( ...
    'PromptString', 'Select subject folder(s):', ...
    'ListString', subfolders, ...
    'SelectionMode', 'multiple', ...
    'Name', 'Select Subjects');
if isempty(ok) || ~ok
    selectedFiles = {};
    return;
end

selectedFiles = {};
for idx = selectedIdx(:)'
    subjectFolder = subfolders{idx};
    candidateFiles = dir(fullfile(rootFolder, subjectFolder, '*.mat'));
    for k = 1:numel(candidateFiles)
        fileName = candidateFiles(k).name;
        tokens = regexp(fileName, fileNameFormat, 'names');
        if isempty(tokens)
            continue; % if the file does not match fileNameFormat
        end
        selectedFiles{end+1, 1} = fullfile(rootFolder, subjectFolder, fileName); %#ok<AGROW>
    end
end
selectedFiles = unique(selectedFiles, 'stable');
end
