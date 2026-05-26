function [resultsTable, metaTable] = analyzeFiles(selectedFiles)
%analyzeFiles Analyze multiple Bpod session .mat files.
%   [resultsTable, metaTable] = multi_session.analyzeFiles(selectedFiles)
%   loads each selected file and extracts per-stimulus and session meta
%   information using multi_session.analyzeSingleSession.

if nargin < 1 || isempty(selectedFiles)
    resultsTable = table();
    metaTable = table();
    return;
end
if ischar(selectedFiles)
    selectedFiles = {selectedFiles};
end

resultsTable = table();
metaTable = table();
for fileIdx = 1:numel(selectedFiles)
    absolutePath = selectedFiles{fileIdx};
    if ~exist(absolutePath, 'file')
        warning('File not found: %s. Skipping.', absolutePath);
        continue;
    end

    [~, nameOnly, extension] = fileparts(absolutePath);
    filename = [nameOnly, extension];
    fprintf('========================================\n');
    fprintf('Processing file %d of %d: %s\n', fileIdx, numel(selectedFiles), filename);
    fprintf('File path: %s\n', absolutePath);

    switch lower(extension)
        case '.mat'
            try
                currentSessionData = load(absolutePath);
                fprintf('MAT file loaded successfully\n');
            catch err
                warning('Failed to load %s: %s', absolutePath, err.message);
                continue;
            end
        otherwise
            warning('Unsupported file type: %s. Skipping this file.', extension);
            continue;
    end

    if isempty(fieldnames(currentSessionData))
        warning('Loaded file contains no variables: %s. Skipping.', filename);
        continue;
    end

    try
        [sessionTable, sessionMetaTable] = multi_session.analyzeSingleSession(currentSessionData, filename);
        sessionTable.FilePath = repmat({absolutePath}, height(sessionTable), 1);
        sessionTable = movevars(sessionTable, 'FilePath', 'Before', 'FileName');
        sessionMetaTable.FilePath = {absolutePath};
        sessionMetaTable = movevars(sessionMetaTable, 'FilePath', 'Before', 'FileName');
        resultsTable = [resultsTable; sessionTable]; %#ok<AGROW>
        metaTable = [metaTable; sessionMetaTable]; %#ok<AGROW>
        fprintf('Current session analysed successfully\n');
    catch err
        warning('Analysis failed for %s: %s', filename, err.message);
    end
end
end
