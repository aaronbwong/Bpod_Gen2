function [selectedRows, sessionSummary] = selectSessionsByAnimal(T, varargin)
%selectSessionsByAnimal Select rows belonging to selected sessions by animal.
%   [selectedRows, sessionSummary] = multi_session.selectSessionsByAnimal(T)
%   selects the latest session for each animal.
%
%   [selectedRows, sessionSummary] = multi_session.selectSessionsByAnimal(T, 'SessionNumber', n)
%   selects the n-th latest session for each animal.
%
%   [selectedRows, sessionSummary] = multi_session.selectSessionsByAnimal(T, 'SessionDate', d)
%   selects all sessions from the specified date or date range.
%
%   [selectedRows, sessionSummary] = multi_session.selectSessionsByAnimal(T, 'PeriodDays', d)
%   selects all sessions within the last d days for each animal.

p = inputParser;
addRequired(p, 'T', @istable);
addParameter(p, 'SessionNumber', 1, @(x) validateattributes(x, {'numeric'}, {'scalar','positive','integer'}));
addParameter(p, 'SessionDate', [], @(x) isempty(x) || isdatetime(x) || ischar(x) || isstring(x));
addParameter(p, 'PeriodDays', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
parse(p, T, varargin{:});

T = p.Results.T;
sessionNumber = p.Results.SessionNumber;
sessionDate = p.Results.SessionDate;
periodDays = p.Results.PeriodDays;
if ischar(sessionDate) || isstring(sessionDate)
    sessionDate = datetime(sessionDate);
end

requiredFields = {'AnimalID','DateTime','FilePath'};
if ~all(ismember(requiredFields, T.Properties.VariableNames))
    error('Table must contain AnimalID, DateTime, and FilePath columns.');
end
if ~isdatetime(T.DateTime)
    error('DateTime must be a datetime array.');
end

selectedRows = T([],:);
sessionSummary = table('Size',[0,6], ...
    'VariableTypes', {'string','double','datetime','datetime','cell','logical'}, ...
    'VariableNames', {'AnimalID','NSessions','DateTime_first','DateTime_last','FilePaths','AggregateSessions'});

animals = unique(T.AnimalID, 'stable');
for i = 1:numel(animals)
    animal = animals{i};
    rows = T(strcmp(T.AnimalID, animal), :);
    rows = sortrows(rows, 'DateTime', 'ascend');
    sessionRows = unique(rows(:, {'FilePath','DateTime'}), 'rows', 'stable');
    if isempty(sessionRows)
        continue;
    end

    [selectedSessionRows, aggregateSessions] = selectSessionRows(sessionRows, sessionNumber, sessionDate, periodDays);
    if isempty(selectedSessionRows)
        continue;
    end

    sessionKeys = strcat(string(rows.FilePath), '||', string(rows.DateTime));
    selectedKeys = strcat(string(selectedSessionRows.FilePath), '||', string(selectedSessionRows.DateTime));
    sessionMask = ismember(sessionKeys, selectedKeys);
    selectedRows = [selectedRows; rows(sessionMask, :)]; %#ok<AGROW>

    filePaths = cellstr(selectedSessionRows.FilePath);
    sessionSummary = [sessionSummary; {string(animal), height(selectedSessionRows), min(selectedSessionRows.DateTime), max(selectedSessionRows.DateTime), {filePaths}, aggregateSessions}]; %#ok<AGROW>
end
end

function [selectedRows, aggregateSessions] = selectSessionRows(sessionRows, sessionNumber, sessionDate, periodDays)
    aggregateSessions = false;
    selectedRows = sessionRows([],:);

    if ~isempty(sessionDate)
        if isscalar(sessionDate)
            sessionDate = dateshift(sessionDate, 'start', 'day');
            startTime = sessionDate;
            endTime = dateshift(sessionDate, 'end', 'day');
        elseif numel(sessionDate) == 2
            sessionDate = sort(sessionDate);
            startTime = dateshift(sessionDate(1), 'start', 'day');
            endTime = dateshift(sessionDate(2), 'end', 'day');
        else
            error('SessionDate must be a single date or a two-element date range.');
        end
        windowMask = sessionRows.DateTime >= startTime & sessionRows.DateTime <= endTime;
        selectedRows = sessionRows(windowMask, :);
        if isempty(selectedRows)
            return;
        end
        aggregateSessions = height(selectedRows) > 1;
        return;
    elseif ~isempty(periodDays)
        endTime = max(sessionRows.DateTime);
        startTime = endTime - days(periodDays);
        windowMask = sessionRows.DateTime >= startTime & sessionRows.DateTime <= endTime;
        selectedRows = sessionRows(windowMask, :);
        if isempty(selectedRows)
            return;
        end
        aggregateSessions = height(selectedRows) > 1;
        return;
    end

    sessionNumber = min(sessionNumber, height(sessionRows));
    selectedRows = sessionRows(end-sessionNumber+1, :);
end