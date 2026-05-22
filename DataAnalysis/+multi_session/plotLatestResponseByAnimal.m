function summaryTable = plotLatestResponseByAnimal(T, varargin)
%plotLatestResponseByAnimal Summarize stimulus responses by animal and plot bars.
%   summaryTable = multi_session.summarizeLatestResponseByAnimal(T)
%   summarizes the last 7 days from the latest record in T.DateTime,
%   including catch trials, and shows one subplot per AnimalID.
%
%   summaryTable = multi_session.summarizeLatestResponseByAnimal(T, 'PeriodDays', d)
%   allows changing the lookback period in days.
%
%   summaryTable = multi_session.summarizeLatestResponseByAnimal(T, 'Plot', false)
%   suppresses plotting.

p = inputParser;
addRequired(p, 'T', @istable);
addParameter(p, 'PeriodDays', 7, @(x) validateattributes(x, {'numeric'}, {'scalar','positive'}));
addParameter(p, 'Plot', true, @(x) islogical(x) || (isnumeric(x) && isscalar(x)));
parse(p, T, varargin{:});

T = p.Results.T;
periodDays = p.Results.PeriodDays;
doPlot = logical(p.Results.Plot);

if ~ismember('DateTime', T.Properties.VariableNames) || ~isdatetime(T.DateTime)
    error('Table must contain DateTime as datetime array.');
end
if ~all(ismember({'AnimalID','VibFreq','VibAmp','NTrials','LeftRes','RightRes'}, T.Properties.VariableNames))
    error('Table must contain AnimalID, VibFreq, VibAmp, NTrials, LeftRes, and RightRes fields.');
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
    summaryTable = table();
    return;
end

% Aggregate counts by animal and stimulus combination
summaryTable = varfun(@sum, Tperiod, ...
    'InputVariables', {'NTrials','LeftRes','RightRes'}, ...
    'GroupingVariables', {'AnimalID','VibFreq','VibAmp'});
summaryTable.Properties.VariableNames{'GroupCount'} = 'Nrows';
summaryTable.Properties.VariableNames{'sum_NTrials'} = 'NTrials';
summaryTable.Properties.VariableNames{'sum_LeftRes'} = 'LeftRes';
summaryTable.Properties.VariableNames{'sum_RightRes'} = 'RightRes';

% Keep catch trials last within each animal
isCatch = summaryTable.VibFreq == 0;
summaryTable.SortKey = double(isCatch);
summaryTable = sortrows(summaryTable, {'AnimalID','SortKey','VibFreq','VibAmp'});
summaryTable.SortKey = []; 

% Add proportions in table for convenience
summaryTable.RightFrac = summaryTable.RightRes ./ summaryTable.NTrials;
summaryTable.LeftFrac = summaryTable.LeftRes ./ summaryTable.NTrials;
summaryTable.RightFrac(summaryTable.NTrials == 0) = 0;
summaryTable.LeftFrac(summaryTable.NTrials == 0) = 0;

if doPlot
    animals = unique(summaryTable.AnimalID);
    nAnimals = numel(animals);
    nCols = max(ceil(sqrt(nAnimals)),3);
    nRows = ceil(nAnimals / nCols);
    figure('Position', [100, 100, 1400, 800]);

    for i = 1:nAnimals
        animal = animals{i};
        mask = strcmp(summaryTable.AnimalID, animal);
        animalTable = summaryTable(mask, :);
        if isempty(animalTable)
            continue;
        end

        ax = subplot(nRows, nCols, i);
        x = 1:height(animalTable);
        y = [animalTable.LeftFrac,animalTable.RightFrac];
        barHandle = bar(ax, x, y, 'stacked');
        barHandle(1).FaceColor = [0.2 0.4 0.8]; % Blue for left responses
        barHandle(2).FaceColor = [0.8 0.2 0.2]; % Red for right responses

        xticklabels = cell(height(animalTable), 1);
        for j = 1:height(animalTable)
            if animalTable.VibFreq(j) == 0
                xticklabels{j} = 'catch';
            else
                xticklabels{j} = sprintf('%gHz @ %.3g', animalTable.VibFreq(j), animalTable.VibAmp(j));
            end
        end
        ax.XTick = x;
        ax.XTickLabel = xticklabels;
        ax.XTickLabelRotation = 45;
        ax.TickLabelInterpreter = 'tex';
        ylabel('Response fraction');
        ylim([0 1]);
        title(sprintf('Animal: %s', animal));
        legend({'Left','Right'}, 'Location', 'northoutside');
        grid on;
    end
    dateRange = string([startTime, endTime], 'yyyy-MM-dd');
    dateRangeStr = sprintf('%s to %s', dateRange(1), dateRange(2));
    sgtitle(sprintf('Stimulus response fractions (%s)', dateRangeStr));
end
end
