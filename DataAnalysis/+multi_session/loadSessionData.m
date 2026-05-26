function SessionData = loadSessionData(filePath)
%loadSessionData Load SessionData from a MAT file.
%   SessionData = multi_session.loadSessionData(filePath)
%   supports files where SessionData is stored directly as a top-level
%   variable or inside a struct with a SessionData field.

if nargin < 1 || isempty(filePath)
    error('A valid file path is required.');
end

if ~exist(filePath, 'file')
    error('File does not exist: %s', filePath);
end

loadedData = load(filePath);

if isfield(loadedData, 'SessionData')
    SessionData = loadedData.SessionData;
    return;
end

vars = fieldnames(loadedData);
for i = 1:numel(vars)
    candidate = loadedData.(vars{i});
    if isstruct(candidate) && isfield(candidate, 'RawEvents')
        SessionData = candidate;
        return;
    end
end

error('Could not find SessionData in %s.', filePath);
