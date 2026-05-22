function plotResponseLatencyCDFByAnimal(T, varargin)
%plotResponseLatencyCDFByAnimal Plot response latency CDFs by animal.
%   multi_session.plotResponseLatencyCDFByAnimal(T)
%   plots the cumulative distribution of first response latency across
%   all trials in the latest period, grouped by animal. Catch trial
%   responses are shown as a separate curve per animal.
%
%   multi_session.plotResponseLatencyCDFByAnimal(T, 'PeriodDays', d)
%   uses a custom lookback period in days.
%
%   multi_session.plotResponseLatencyCDFByAnimal(T, 'ResWin', r)
%   uses a fixed response window for all animals.
%
%   multi_session.plotResponseLatencyCDFByAnimal(T, 'Plot', false)
%   disables plotting and only validates input.

p = inputParser;
addRequired(p, 'T', @istable);
addParameter(p, 'PeriodDays', 7, @(x) validateattributes(x, {'numeric'}, {'scalar','positive'}));
addParameter(p, 'ResWin', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'BoundaryFreq', 550, @(x) validateattributes(x, {'numeric'}, {'scalar','nonnegative'}));
addParameter(p, 'LowColor', [0.8, 0.2, 0.2], @(x) validateattributes(x, {'numeric'}, {'vector','numel',3,'>=',0,'<=',1}));
addParameter(p, 'HighColor', [0.2, 0.4, 0.8], @(x) validateattributes(x, {'numeric'}, {'vector','numel',3,'>=',0,'<=',1}));
addParameter(p, 'CatchColor', [0.2, 0.7, 0.2], @(x) validateattributes(x, {'numeric'}, {'vector','numel',3,'>=',0,'<=',1}));
addParameter(p, 'Plot', true, @(x) islogical(x) || (isnumeric(x) && isscalar(x)));
parse(p, T, varargin{:});

T = p.Results.T;
periodDays = p.Results.PeriodDays;
resWin = p.Results.ResWin;
boundaryFreq = p.Results.BoundaryFreq;
lowColor = p.Results.LowColor;
highColor = p.Results.HighColor;
catchColor = p.Results.CatchColor;
doPlot = logical(p.Results.Plot);

requiredVars = {'AnimalID','DateTime','NTrials','VibFreq','ResponseLatenciesLeft','ResponseLatenciesRight','ResponseLatenciesCatch'};
if ~all(ismember(requiredVars, T.Properties.VariableNames))
    error('Table must contain the required fields: %s.', strjoin(requiredVars, ', '));
end
if ~isdatetime(T.DateTime)
    error('DateTime must be a datetime array.');
end

validMask = ~isnat(T.DateTime);
if ~any(validMask)
    error('No valid DateTime values found in table.');
end

T = T(validMask, :);
endTime = max(T.DateTime);
startTime = endTime - days(periodDays);
periodMask = T.DateTime >= startTime & T.DateTime <= endTime;
Tperiod = T(periodMask, :);

if isempty(Tperiod)
    warning('No records found in the last %d days.', periodDays);
    return;
end

animalIDs = unique(Tperiod.AnimalID);
if isempty(animalIDs)
    warning('No animals found in the selected period.');
    return;
end

allLatencies = [];
for i = 1:height(Tperiod)
    allLatencies = [allLatencies; Tperiod.ResponseLatenciesLeft{i}(:); Tperiod.ResponseLatenciesRight{i}(:)]; %#ok<AGROW>
end
if isempty(allLatencies)
    warning('No response latencies available in the selected period.');
    return;
end

if isempty(resWin)
    if ismember('ResWin', Tperiod.Properties.VariableNames)
        resWin = min(Tperiod.ResWin);
    else
        resWin = max(allLatencies);
    end
end

if doPlot
    nAnimals = numel(animalIDs);
    nCols = min(max(ceil(sqrt(nAnimals)), 2), 4);
    nRows = ceil(nAnimals / nCols);
    figure('Position', [100, 100, 1400, 800]);

    for i = 1:nAnimals
        animal = animalIDs{i};
        animalMask = strcmp(Tperiod.AnimalID, animal);
        animalRows = Tperiod(animalMask, :);

        lowMask = animalRows.VibFreq > 0 & animalRows.VibFreq <= boundaryFreq;
        highMask = animalRows.VibFreq > boundaryFreq;
        catchMask = animalRows.VibFreq == 0;

        [lowLat, lowTrials] = aggregateLatency(animalRows, lowMask, true);
        [highLat, highTrials] = aggregateLatency(animalRows, highMask, true);
        [catchLat, catchTrials] = aggregateLatency(animalRows, catchMask, false);

        ax = subplot(nRows, nCols, i);
        hold(ax, 'on');
        if lowTrials > 0
            plotCategory(ax, lowLat, lowTrials, resWin, lowColor, sprintf('Low (resp=%d/%d)', numel(lowLat), lowTrials));
        end
        if highTrials > 0
            plotCategory(ax, highLat, highTrials, resWin, highColor, sprintf('High (resp=%d/%d)', numel(highLat), highTrials));
        end
        if catchTrials > 0
            plotCategory(ax, catchLat, catchTrials, resWin, catchColor, sprintf('Catch (resp=%d/%d)', numel(catchLat), catchTrials));
        end

        xlabel(ax, 'Response latency (s)');
        ylabel(ax, 'Cumulative proportion');
        title(ax, sprintf('Animal: %s', animal));
        xlim(ax, [0, resWin]);
        ylim(ax, [0, 1]);
        grid(ax, 'on');
        % if i == 1
        lgd =     legend(ax, 'Location', 'northwest');
        lgd.Color = 'none';
        lgd.Box = 'off';
        % end
        hold(ax, 'off');
    end
    sgtitle(sprintf('Response latency CDF by animal (%s to %s)', string(startTime, 'yyyy-MM-dd'), string(endTime, 'yyyy-MM-dd')));
end
end

function [latencies, totalTrials] = aggregateLatency(rows, mask, includeSides)
latencies = [];
totalTrials = sum(rows.NTrials(mask));
for k = find(mask(:)')
    if includeSides
        latencies = [latencies; rows.ResponseLatenciesLeft{k}(:); rows.ResponseLatenciesRight{k}(:)]; %#ok<AGROW>
    else
        latencies = [latencies; rows.ResponseLatenciesCatch{k}(:)]; %#ok<AGROW>
    end
end
end

function plotCategory(ax, latencies, totalTrials, resWin, color, labelText)
if isempty(latencies)
    return;
end
latencies = sort(latencies(:));
[uniq, ~, ic] = unique(latencies);
counts = accumarray(ic, 1);
yvals = cumsum(counts) ./ totalTrials;
xvals = [0; uniq; resWin];
yplot = [0; yvals; yvals(end)];
stairs(ax, xvals, yplot, 'Color', color, 'LineWidth', 2, 'DisplayName', labelText);
end