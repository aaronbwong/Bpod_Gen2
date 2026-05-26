function summaryTable = plotLickIntervalsByAnimal(T, varargin)
%plotLickIntervalsByAnimal Plot lick interval histograms for the latest session of each animal.
%   summaryTable = multi_session.plotLickIntervalsByAnimal(T)
%   uses the most recent valid session for each AnimalID and loads raw
%   SessionData from the file path stored in T.FilePath.
%
%   summaryTable = multi_session.plotLickIntervalsByAnimal(T, 'MaxX', 5, 'BinWidth', 0.1)
%   customizes the histogram x-range and bin width.
%
%   summaryTable = multi_session.plotLickIntervalsByAnimal(T, 'Plot', false)
%   computes the summary table without drawing figures.

p = inputParser;
addRequired(p, 'T', @istable);
addParameter(p, 'Plot', true, @(x) islogical(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'MaxX', 5, @(x) validateattributes(x, {'numeric'}, {'scalar','positive'}));
addParameter(p, 'BinWidth', 0.1, @(x) validateattributes(x, {'numeric'}, {'scalar','positive'}));
addParameter(p, 'FigurePosition', [100 100 1400 800], @(x) isnumeric(x) && numel(x) == 4);
parse(p, T, varargin{:});

T = p.Results.T;
doPlot = logical(p.Results.Plot);
maxX = p.Results.MaxX;
binWidth = p.Results.BinWidth;
figurePosition = p.Results.FigurePosition;

requiredFields = {'AnimalID', 'DateTime', 'FilePath'};
if ~all(ismember(requiredFields, T.Properties.VariableNames))
    error('Table must contain AnimalID, DateTime, and FilePath columns.');
end
if ~isdatetime(T.DateTime)
    error('DateTime must be a datetime array.');
end

validMask = ~isnat(T.DateTime);
if ~any(validMask)
    error('No valid DateTime values found in table.');
end

T = T(validMask, :);
if isempty(T)
    warning('No valid session rows found.');
    summaryTable = table();
    return;
end

animals = unique(T.AnimalID, 'stable');
summaryRows = cell(numel(animals), 1);

for i = 1:numel(animals)
    animal = animals{i};
    rows = T(strcmp(T.AnimalID, animal), :);
    rows = sortrows(rows, 'DateTime', 'ascend');
    latestRow = rows(end, :);

    filePathCell = latestRow.FilePath(1);
    if iscell(filePathCell)
        filePath = filePathCell{1};
    else
        filePath = filePathCell;
    end
    filePath = char(filePath);

    if ~exist(filePath, 'file')
        warning('Skipping %s: file does not exist: %s', animal, filePath);
        summaryRows{i} = table({animal}, {filePath}, latestRow.DateTime, 0, nan, nan, nan, nan, nan, nan, nan, nan, ...
            'VariableNames', {'AnimalID','FilePath','DateTime','NIntervals','MeanInterval','MedianInterval','MinInterval','MaxInterval','MinQuietTime','MaxQuietTime','MinITI','MaxITI'});
        continue;
    end

    try
        SessionData = multi_session.loadSessionData(filePath);
        intervals = multi_session.getLickIntervals(SessionData);
        [minQuietTime, maxQuietTime, minITI, maxITI] = extractQuietAndITIRange(SessionData);
    catch err
        warning('Failed to load lick intervals for %s: %s', animal, err.message);
        intervals = [];
        minQuietTime = nan;
        maxQuietTime = nan;
        minITI = nan;
        maxITI = nan;
    end

    if isempty(intervals)
        summaryRows{i} = table({animal}, {filePath}, latestRow.DateTime, 0, nan, nan, nan, nan, minQuietTime, maxQuietTime, minITI, maxITI, ...
            'VariableNames', {'AnimalID','FilePath','DateTime','NIntervals','MeanInterval','MedianInterval','MinInterval','MaxInterval','MinQuietTime','MaxQuietTime','MinITI','MaxITI'});
    else
        summaryRows{i} = table({animal}, {filePath}, latestRow.DateTime, numel(intervals), mean(intervals), median(intervals), min(intervals), max(intervals), minQuietTime, maxQuietTime, minITI, maxITI, ...
            'VariableNames', {'AnimalID','FilePath','DateTime','NIntervals','MeanInterval','MedianInterval','MinInterval','MaxInterval','MinQuietTime','MaxQuietTime','MinITI','MaxITI'});
    end
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
        latestRow = summaryTable(i, :);
        if latestRow.NIntervals == 0
            cla(ax);
            text(ax, 0.5, 0.5, 'No lick interval data', 'HorizontalAlignment', 'center', 'FontSize', 12);
            title(ax, sprintf('%s (%s)', animal, string(latestRow.DateTime, 'yyyy-MM-dd HH:mm:ss')));
            xlabel(ax, 'Lick Interval (seconds)');
            ylabel(ax, 'Count');
            continue;
        end

        try
            filePathCell = latestRow.FilePath(1);
            if iscell(filePathCell)
                filePath = filePathCell{1};
            else
                filePath = filePathCell;
            end
            filePath = char(filePath);
            SessionData = multi_session.loadSessionData(filePath);
            intervals = multi_session.getLickIntervals(SessionData);
        catch
            intervals = [];
        end

        if isempty(intervals)
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

            if ~isnan(latestRow.MinQuietTime)
                xline(ax, latestRow.MinQuietTime, '--', 'No-Lick Start', 'Color',[0,.5,0],'LineWidth',1.5,'LabelOrientation', 'horizontal', 'LabelHorizontalAlignment', 'right');
            end
            if ~isnan(latestRow.MaxQuietTime)
                xline(ax, latestRow.MaxQuietTime, '-.', [newline,'No-Lick End'], 'Color',[0,.5,0],'LineWidth',1.5,'LabelOrientation', 'horizontal', 'LabelHorizontalAlignment', 'right');
            end
            if ~isnan(latestRow.MinITI)
                xline(ax, latestRow.MinITI, '--', 'ITI Min', 'Color',[.8,0,0],'LineWidth',1.5, 'LabelOrientation',  'horizontal', 'LabelHorizontalAlignment', 'right');
            end
            if ~isnan(latestRow.MaxITI)
                xline(ax, latestRow.MaxITI, '-.', [newline,'ITI Max'], 'Color',[.8,0,0],'LineWidth',1.5, 'LabelOrientation',  'horizontal', 'LabelHorizontalAlignment', 'right');
            end
        end

        title(ax, sprintf('%s (%s)', animal, string(latestRow.DateTime, 'yyyy-MM-dd HH:mm:ss')));
        xlabel(ax, 'Lick Interval (seconds)');
    end

    linkaxes(axesHandles, 'x');
    sgtitle('Most Recent Session Lick Interval Histograms by Animal');
end

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
end