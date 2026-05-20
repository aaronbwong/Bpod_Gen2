function selectedFiles = selectFilesFromFolder(folderPath)
%selectFilesFromFolder Return all .mat files in a folder.
%   selectedFiles = multi_session.selectFilesFromFolder(folderPath)
%   returns a cell array of full paths to .mat files located in the
%   specified folder. This does not recurse into subfolders.

if nargin < 1 || isempty(folderPath)
    folderPath = pwd;
end
if ~exist(folderPath, 'dir')
    error('Folder does not exist: %s', folderPath);
end

listing = dir(fullfile(folderPath, '*.mat'));
selectedFiles = fullfile(folderPath, {listing.name});
selectedFiles = selectedFiles(:);
end
