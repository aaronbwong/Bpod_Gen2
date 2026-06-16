function summaryTable = plotLickIntervalsByAnimal(sl, varargin)
%plotLickIntervalsByAnimal Plot lick interval histograms for selected session(s) of each animal.
%   summaryTable = multi_session.plotLickIntervalsByAnimal(sl)
%   uses the most recent valid session for each AnimalID and loads raw
%   SessionData from the file path stored in sl.FilePath.
%
%   summaryTable = multi_session.plotLickIntervalsByAnimal(sl, 'MaxX', 5, 'BinWidth', 0.1)
%   customizes the histogram x-range and bin width.
%
%   summaryTable = multi_session.plotLickIntervalsByAnimal(sl, 'SessionNumber', 2)
%   plots the second-most recent session per animal.
%
%   summaryTable = multi_session.plotLickIntervalsByAnimal(sl, 'SessionDate', '2026-05-25')
%   plots all sessions from that date.
%
%   summaryTable = multi_session.plotLickIntervalsByAnimal(sl, 'PeriodDays', 7)
%   plots the latest session within the last 7 days.
%
%   summaryTable = multi_session.plotLickIntervalsByAnimal(sl, 'Plot', false)
%   computes the summary table without drawing figures.

p = inputParser;
addRequired(p, 'sl', @istable);
addParameter(p, 'Plot', true, @(x) islogical(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'MaxX', 5, @(x) validateattributes(x, {'numeric'}, {'scalar','positive'}));
addParameter(p, 'BinWidth', 0.1, @(x) validateattributes(x, {'numeric'}, {'scalar','positive'}));
addParameter(p, 'FigurePosition', [100 100 1400 800], @(x) isnumeric(x) && numel(x) == 4);
addParameter(p, 'SessionNumber', 1, @(x) validateattributes(x, {'numeric'}, {'scalar','positive','integer'}));
addParameter(p, 'SessionDate', [], @(x) isempty(x) || isdatetime(x) || ischar(x) || isstring(x));
addParameter(p, 'PeriodDays', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
parse(p, sl, varargin{:});

sl = p.Results.sl;
doPlot = logical(p.Results.Plot);
maxX = p.Results.MaxX;
binWidth = p.Results.BinWidth;
figurePosition = p.Results.FigurePosition;
sessionNumber = p.Results.SessionNumber;
sessionDate = p.Results.SessionDate;
periodDays = p.Results.PeriodDays;
if ischar(sessionDate) || isstring(sessionDate)
    sessionDate = datetime(sessionDate);
end

requiredFields = {'AnimalID', 'DateTime', 'FilePath'};
if ~all(ismember(requiredFields, sl.Properties.VariableNames))
    error('Table must contain AnimalID, DateTime, and FilePath columns.');
end
if ~isdatetime(sl.DateTime)
    error('DateTime must be a datetime array.');
end

validMask = ~isnat(sl.DateTime);
if ~any(validMask)
    error('No valid DateTime values found in table.');
end

sl = sl(validMask, :);
if isempty(sl)
    warning('No valid session rows found.');
    summaryTable = table();
    return;
end

animals = unique(sl.AnimalID, 'stable');
summaryRows = cell(numel(animals), 1);

for i = 1:numel(animals)
    animal = animals{i};
    rows = sl(strcmp(sl.AnimalID, animal), :);
    rows = sortrows(rows, 'DateTime', 'ascend');

    [selectedRowsForAnimal, summaryRow] = multi_session.selectSessionsByAnimal(rows, ...
        'SessionNumber', sessionNumber, ...
        'SessionDate', sessionDate, ...
        'PeriodDays', periodDays);
    if isempty(selectedRowsForAnimal)
        warning('No selectable session found for %s.', animal);
        continue;
    end

    filePathEntry = summaryRow.FilePaths(1);
    NselectedSessions = summaryRow.NSessions(1);
    firstDate = summaryRow.DateTime_first(1);
    lastDate = summaryRow.DateTime_last(1);

    intervals = [];
    minQuietTime = nan;
    maxQuietTime = nan;
    minITI = nan;
    maxITI = nan;

    filePathsToLoad = unique(selectedRowsForAnimal.FilePath, 'stable');
    for j = 1:numel(filePathsToLoad)
        filePathCandidate = filePathsToLoad{j};
        if iscell(filePathCandidate)
            filePathCandidate = filePathCandidate{1};
        end
        filePathCandidate = char(filePathCandidate);

        if ~exist(filePathCandidate, 'file')
            warning('Skipping %s: file does not exist: %s', animal, filePathCandidate);
            continue;
        end

        try
            SessionData = multi_session.loadSessionData(filePathCandidate);
            sessionIntervals = multi_session.getLickIntervals(SessionData);
            intervals = [intervals; sessionIntervals(:)]; %#ok<AGROW>
            [sessionMinQuiet, sessionMaxQuiet, sessionMinITI, sessionMaxITI] = extractQuietAndITIRange(SessionData);
            minQuietTime = min([minQuietTime, sessionMinQuiet]);
            maxQuietTime = max([maxQuietTime, sessionMaxQuiet]);
            minITI = min([minITI, sessionMinITI]);
            maxITI = max([maxITI, sessionMaxITI]);
        catch err
            warning('Failed to load lick intervals for %s from %s: %s', animal, filePathCandidate, err.message);
        end
    end

    NIntervals = numel(intervals);
    if isempty(intervals)
        intervals = nan;
    end
    summaryRows{i} = table({animal}, filePathEntry, NselectedSessions, firstDate, lastDate, NIntervals, mean(intervals), median(intervals), min(intervals), max(intervals), minQuietTime, maxQuietTime, minITI, maxITI, ...
        'VariableNames', {'AnimalID','FilePath','NSessions','DateTime_first','DateTime_last','NIntervals','MeanInterval','MedianInterval','MinInterval','MaxInterval','MinQuietTime','MaxQuietTime','MinITI','MaxITI'});
end

summaryTable = vertcat(summaryRows{:});

if doPlot && ~isempty(summaryTable)
    nAnimals = height(summaryTable);
    nCols = max(ceil(sqrt(nAnimals)), 1);
    nRows = ceil(nAnimals / nCols);
    figure('Position', figurePosition);
    axesHandles = gobjects(nAnimals, 1);

    for i = 1:nAnimals
        ax = subplot(nRows, nCols, i);
        axesHandles(i) = ax;
        animal = summaryTable.AnimalID{i};
        animalRow = summaryTable(i, :);
        if animalRow.NIntervals == 0
            cla(ax);
            text(ax, 0.5, 0.5, 'No lick interval data', 'HorizontalAlignment', 'center', 'FontSize', 12);
            title(ax, sprintf('%s (%s)', animal, string(animalRow.DateTime_first, 'yyyy-MM-dd HH:mm:ss')));
            xlabel(ax, 'Lick Interval (seconds)');
            ylabel(ax, 'Count');
            continue;
        end

        try
            filePathEntry = animalRow.FilePath{1};
            if iscell(filePathEntry)
                filePaths = filePathEntry;
            else
                filePaths = {char(filePathEntry)};
            end
            intervals = [];
            for j = 1:numel(filePaths)
                filePathCandidate = filePaths{j};
                if iscell(filePathCandidate)
                    filePathCandidate = filePathCandidate{1};
                end
                filePathCandidate = char(filePathCandidate);

                if ~exist(filePathCandidate, 'file')
                    warning('Skipping missing file for plot: %s', filePathCandidate);
                    continue;
                end
                SessionData = multi_session.loadSessionData(filePathCandidate);
                sessionIntervals = multi_session.getLickIntervals(SessionData);
                intervals = [intervals; sessionIntervals(:)];
            end
        catch
            intervals = [];
        end

        if NIntervals == 0 || all(isnan(intervals))
            cla(ax);
            text(ax, 0.5, 0.5, 'No lick interval data', 'HorizontalAlignment', 'center', 'FontSize', 12);
        else
            histogram(ax, intervals, 'BinWidth', binWidth, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'black');
            set(ax, 'YScale', 'log');
            xlim(ax, [0, maxX]);
            if maxX <= 5
                xticks(ax, 0:0.5:maxX);
            end
            ylabel(ax, 'Count');
            grid(ax, 'on');

            if ~isnan(animalRow.MinQuietTime)
                xline(ax, animalRow.MinQuietTime, '--', 'No-Lick Start', 'Color',[0,.5,0],'LineWidth',1.5,'LabelOrientation', 'horizontal', 'LabelHorizontalAlignment', 'right');
            end
            if ~isnan(animalRow.MaxQuietTime)
                xline(ax, animalRow.MaxQuietTime, '-.', [newline,'No-Lick End'], 'Color',[0,.5,0],'LineWidth',1.5,'LabelOrientation', 'horizontal', 'LabelHorizontalAlignment', 'right');
            end
            if ~isnan(animalRow.MinITI)
                xline(ax, animalRow.MinITI, '--', 'ITI Min', 'Color',[.8,0,0],'LineWidth',1.5, 'LabelOrientation',  'horizontal', 'LabelHorizontalAlignment', 'right');
            end
            if ~isnan(animalRow.MaxITI)
                xline(ax, animalRow.MaxITI, '-.', [newline,'ITI Max'], 'Color',[.8,0,0],'LineWidth',1.5, 'LabelOrientation',  'horizontal', 'LabelHorizontalAlignment', 'right');
            end
        end
        if animalRow.NSessions == 1
            % single session
            titleStr = sprintf('%s (%s)', animal, string(animalRow.DateTime_first, 'yyyy-MM-dd HH:mm:ss'));
        elseif strcmp(string(animalRow.DateTime_first, 'yyyy-MM-dd'), string(animalRow.DateTime_last, 'yyyy-MM-dd'))
            % aggregate but single day
            titleStr = sprintf('%s (%s: %d sessions)', animal, string(animalRow.DateTime_first, 'yyyy-MM-dd'), animalRow.NSessions);
        else
            % multiple days
            titleStr = sprintf('%s (%s - %s: %d sessions)', animal, string(animalRow.DateTime_first, 'yyyy-MM-dd'), string(animalRow.DateTime_last, 'yyyy-MM-dd'), animalRow.NSessions);
        end
        title(ax, titleStr);
        xlabel(ax, 'Lick Interval (seconds)');
    end

    linkaxes(axesHandles, 'x');
    sgtitle('Selected Session Lick Interval Histograms by Animal');
end %if
end % function plotLickIntervalsByAnimal()

function [minQuietTime, maxQuietTime, minITI, maxITI] = extractQuietAndITIRange(SessionData)
    minQuietTime = nan;
    maxQuietTime = nan;
    minITI = nan;
    maxITI = nan;

    if isfield(SessionData, 'QuietTime')
        quietTimeValues = SessionData.QuietTime(~isnan(SessionData.QuietTime));
        if ~isempty(quietTimeValues)
            minQuietTime = min(quietTimeValues);
            maxQuietTime = max(quietTimeValues);
        end
    elseif isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        if isfield(SessionData.TrialSettings(1), 'GUI')
            if isfield(SessionData.TrialSettings(1).GUI, 'MinQuietTime') && isfield(SessionData.TrialSettings(1).GUI, 'MaxQuietTime')
                minQuietTime = SessionData.TrialSettings(1).GUI.MinQuietTime;
                maxQuietTime = SessionData.TrialSettings(1).GUI.MaxQuietTime;
            end
        end
    end

    if isfield(SessionData, 'TrialSettings') && ~isempty(SessionData.TrialSettings)
        if isfield(SessionData.TrialSettings(1), 'GUI')
            if isfield(SessionData.TrialSettings(1).GUI, 'MinITI')
                minITI = SessionData.TrialSettings(1).GUI.MinITI;
            end
            if isfield(SessionData.TrialSettings(1).GUI, 'MaxITI')
                maxITI = SessionData.TrialSettings(1).GUI.MaxITI;
            end
        end
    end
end

