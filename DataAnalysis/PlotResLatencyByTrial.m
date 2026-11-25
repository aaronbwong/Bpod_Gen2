function PlotResLatencyByTrial(SessionData, varargin)
    % PlotResLatencyByTrial - Plot response latency as a function of trial number
    %
    % Latency is the time from stimulus start to the first lick (BNC1High or
    % BNC2High, whichever comes first), same definition as PlotResLatency.
    % Color indicates trial type & stimulus (catch / correct side + VibFreq + VibAmp),
    % marker indicates trial outcome:
    %   'o' - hit (reward delivered after a lick)
    %   's' - manually rewarded (Condition6)
    %   'x' - wrong (lick in a non-catch trial, no reward)
    %   '^' - false alarm (lick in a catch trial)
    % Trials without a lick have no latency and are not drawn.
    %
    % Inputs:
    %   SessionData - Session data structure
    %   Optional name-value pairs:
    %     'FigureHandle' - figure handle (optional, for activation in online mode)
    %     'Axes'         - axes handle (optional, creates new figure if not provided)
    %     'FigureName'   - name for new figure (default: 'Response Latency by Trial')
    %     'MaxLatency'   - y limit in ms used only if ResWin is unavailable (default: 5000)
    %
    % Usage:
    %   Online:  PlotResLatencyByTrial(BpodSystem.Data, 'FigureHandle', customPlotFig, 'Axes', ax);
    %   Offline: PlotResLatencyByTrial(SessionData);

    p = inputParser;
    addParameter(p, 'FigureHandle', [], @(x) isempty(x) || isgraphics(x, 'figure'));
    addParameter(p, 'Axes', [], @(x) isempty(x) || isgraphics(x, 'axes'));
    addParameter(p, 'FigureName', 'Response Latency by Trial', @ischar);
    addParameter(p, 'MaxLatency', 5000, @isnumeric);
    parse(p, varargin{:});

    tTotal = tic;
    tStep = tic;
    customPlotFig = p.Results.FigureHandle;
    ax = p.Results.Axes;
    figureName = p.Results.FigureName;
    maxLatency = p.Results.MaxLatency;

    if ~isempty(customPlotFig) && isvalid(customPlotFig)
        figure(customPlotFig);
    end

    if isempty(ax)
        figure('Name', figureName, 'Position', [100 100 1000 600]);
        ax = axes('Position', [0.1 0.15 0.85 0.75]);
    end

    if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
        warning('SessionData.RawEvents.Trial not found');
        showMessage(ax, 'No data available', customPlotFig);
        return;
    end

    if isfield(SessionData, 'nTrials')
        nTrials = SessionData.nTrials;
    else
        nTrials = length(SessionData.RawEvents.Trial);
    end
    nTrials = min(nTrials, length(SessionData.RawEvents.Trial));

    if nTrials == 0
        showMessage(ax, 'No trials available', customPlotFig);
        return;
    end

    tStep = logTime('setup (figure/axes/input checks)', tStep);

    %% Per-trial stimulus / trial type information
    vibFreq = nan(nTrials, 1);
    vibAmp = nan(nTrials, 1);
    if isfield(SessionData, 'StimTable') && istable(SessionData.StimTable)
        st = SessionData.StimTable;
        n = min(nTrials, height(st));
        if ismember('VibFreq', st.Properties.VariableNames)
            vibFreq(1:n) = st.VibFreq(1:n);
        end
        if ismember('VibAmp', st.Properties.VariableNames)
            vibAmp(1:n) = st.VibAmp(1:n);
        end
    end

    isCatch = abs(vibFreq) < 1e-9 & abs(vibAmp) < 1e-9;
    if isfield(SessionData, 'IsCatchTrial')
        n = min(nTrials, length(SessionData.IsCatchTrial));
        isCatch(1:n) = isCatch(1:n) | logical(SessionData.IsCatchTrial(1:n)).';
    end

    correctSide = nan(nTrials, 1); % 1 = left, 2 = right
    if isfield(SessionData, 'CorrectSide')
        n = min(nTrials, length(SessionData.CorrectSide));
        correctSide(1:n) = SessionData.CorrectSide(1:n);
    end
    correctSide(isCatch) = 0;

    % Response window per trial (s)
    resWin = nan(nTrials, 1);
    if isfield(SessionData, 'ResWin')
        n = min(nTrials, length(SessionData.ResWin));
        resWin(1:n) = SessionData.ResWin(1:n);
    end

    % Fallback for y-limit: maximum stimulus duration (StimTable.Duration, ms)
    maxStimDur = NaN;
    if isfield(SessionData, 'StimTable') && istable(SessionData.StimTable) && ...
            ismember('Duration', SessionData.StimTable.Properties.VariableNames)
        maxStimDur = max(SessionData.StimTable.Duration(1:min(nTrials, height(SessionData.StimTable))));
    end

    % Marker size encodes amplitude (non-catch trials)
    ampList = unique(vibAmp(~isCatch & ~isnan(vibAmp)));
    sizeList = linspace(5, 11, max(numel(ampList), 2));
    trialSize = 7 * ones(nTrials, 1);
    for a = 1:numel(ampList)
        trialSize(~isCatch & vibAmp == ampList(a)) = sizeList(a);
    end
    tStep = logTime('stimulus/trial type extraction', tStep);

    %% Latency and outcome per trial
    latency = nan(nTrials, 1);  % ms
    outcome = zeros(nTrials, 1); % 0 = no lick, 1 = hit, 2 = manual, 3 = wrong, 4 = false alarm

    for trialNum = 1:nTrials
        trialData = SessionData.RawEvents.Trial{trialNum};

        if ~isfield(trialData, 'States') || ~isfield(trialData.States, 'Stimulus') || ...
                isempty(trialData.States.Stimulus) || isnan(trialData.States.Stimulus(1))
            continue;
        end
        stimulusStartTime = trialData.States.Stimulus(1, 1);

        firstLickTime = NaN;
        if isfield(trialData, 'Events')
            for evName = {'BNC1High', 'BNC2High'}
                if isfield(trialData.Events, evName{1}) && ~isempty(trialData.Events.(evName{1}))
                    t = trialData.Events.(evName{1});
                    t = t(t >= stimulusStartTime);
                    if ~isempty(t) && (isnan(firstLickTime) || t(1) < firstLickTime)
                        firstLickTime = t(1);
                    end
                end
            end
        end
        if isnan(firstLickTime)
            continue;
        end
        latency(trialNum) = (firstLickTime - stimulusStartTime) * 1000;

        rewarded = false;
        for stName = {'LeftReward', 'RightReward'}
            if isfield(trialData.States, stName{1}) && ~all(isnan(trialData.States.(stName{1})(:)))
                rewarded = true;
            end
        end
        manual = isfield(trialData, 'Events') && isfield(trialData.Events, 'Condition6');

        if isCatch(trialNum)
            outcome(trialNum) = 4;
        elseif manual && rewarded
            outcome(trialNum) = 2;
        elseif rewarded
            outcome(trialNum) = 1;
        else
            outcome(trialNum) = 3;
        end
    end

    tStep = logTime('trial loop (latency/outcome)', tStep);

    valid = ~isnan(latency);
    if ~any(valid)
        showMessage(ax, 'No response latencies available', customPlotFig);
        return;
    end

    %% Plot
    axes(ax); %#ok<LAXES>
    cla(ax);
    legend(ax, 'off');
    hold(ax, 'on');

    trialNums = (1:nTrials).';
    markers = {'o', 's', 'x', '^'};
    markerNames = {'Hit', 'Manual reward', 'Wrong', 'False alarm'};

    % Color group = trial type + frequency (amplitude is shown as marker size)
    [groups, ~, groupIdx] = unique([correctSide, vibFreq], 'rows');
    nGroups = size(groups, 1);
    boundaryFreq = NaN;
    if isfield(SessionData, 'StimParams') && isfield(SessionData.StimParams, 'Vibration') && ...
            isfield(SessionData.StimParams.Vibration, 'BoundaryFreq')
        boundaryFreq = SessionData.StimParams.Vibration.BoundaryFreq;
    end
    colors = groupColors(groups, boundaryFreq);
    tStep = logTime('grouping/colors', tStep);

    for g = 1:nGroups
        for o = 1:4
            sel = valid & groupIdx == g & outcome == o;
            for sz = unique(trialSize(sel)).'
                s2 = sel & trialSize == sz;
                plot(ax, trialNums(s2), latency(s2), markers{o}, ...
                    'Color', colors(g, :), 'MarkerFaceColor', filledColor(markers{o}, colors(g, :)), ...
                    'MarkerSize', sz, 'LineWidth', 1.2, 'HandleVisibility', 'off');
            end
        end
    end

    tStep = logTime('plotting data points', tStep);

    % Legend: dummy handles for color groups, outcome markers and amplitude sizes
    legHandles = gobjects(0);
    legLabels = {};
    for g = 1:nGroups
        if ~any(valid & groupIdx == g); continue; end
        legHandles(end+1) = plot(ax, NaN, NaN, 's', 'Color', colors(g, :), ...
            'MarkerFaceColor', colors(g, :), 'MarkerSize', 6); %#ok<AGROW>
        legLabels{end+1} = groupLabel(groups(g, :)); %#ok<AGROW>
    end
    for o = 1:4
        if ~any(outcome == o); continue; end
        legHandles(end+1) = plot(ax, NaN, NaN, markers{o}, 'Color', 'k', ...
            'MarkerFaceColor', filledColor(markers{o}, 'k'), 'MarkerSize', 6); %#ok<AGROW>
        legLabels{end+1} = markerNames{o}; %#ok<AGROW>
    end
    for a = 1:numel(ampList)
        legHandles(end+1) = plot(ax, NaN, NaN, 'o', 'Color', [0.3 0.3 0.3], ...
            'MarkerFaceColor', [0.3 0.3 0.3], 'MarkerSize', sizeList(a)); %#ok<AGROW>
        legLabels{end+1} = sprintf('Amp %g', ampList(a)); %#ok<AGROW>
    end
    legend(ax, legHandles, legLabels, 'Location', 'eastoutside', 'Interpreter', 'none');

    tStep = logTime('legend', tStep);

    title(ax, ['Response latency (n=' num2str(sum(valid)) ' first licks / ' num2str(nTrials) ' trials)']);
    xlabel(ax, 'Trial');
    ylabel(ax, 'Delay (ms)');
    maxResWin = max(resWin) * 1000;
    if isnan(maxResWin) || maxResWin <= 0
        maxResWin = maxStimDur; % fallback: longest stimulus duration (ms)
    end
    if isnan(maxResWin) || maxResWin <= 0
        maxResWin = maxLatency;
    end
    ylim(ax, [0 maxResWin]);
    xlim(ax, [0.5 nTrials + 0.5]);
    grid(ax, 'on');
    tStep = logTime('axes formatting', tStep);

    if ~isempty(customPlotFig)
        drawnow;
        logTime('drawnow', tStep);
    end
    logTime('TOTAL', tTotal);
end

function tNew = logTime(label, t)
    fprintf('[PlotResLatencyByTrial] %-40s %7.1f ms\n', label, toc(t) * 1000);
    tNew = tic;
end

function colors = groupColors(groups, boundaryFreq)
    % groups = [correctSide, vibFreq] rows. Left: blue, right: red, catch: gray.
    % Shade is an ordinal scale within each side: frequencies are ranked by
    % distance from the boundary frequency (SessionData.StimParams.Vibration.BoundaryFreq),
    % with equal steps from light (nearest) to darkest (furthest). If the boundary
    % is not stored, the geometric center of the tested range is used.
    nGroups = size(groups, 1);
    colors = repmat([0.5 0.5 0.5], nGroups, 1);
    base = {[0.1 0.1 0.9], [0.9 0.1 0.1]};
    isStim = ismember(groups(:, 1), [1 2]) & groups(:, 2) > 0;
    freqs = groups(isStim, 2);
    if isempty(freqs); return; end
    if isnan(boundaryFreq) || boundaryFreq <= 0
        boundaryFreq = sqrt(min(freqs) * max(freqs));
    end
    dist = abs(log(groups(:, 2) ./ boundaryFreq));
    for side = 1:2
        idx = find(isStim & groups(:, 1) == side);
        if isempty(idx); continue; end
        [~, ~, rank] = unique(round(dist(idx), 6)); % ordinal rank, 1 = nearest boundary
        nRank = max(rank);
        for k = 1:numel(idx)
            if nRank > 1
                mix = 0.65 * (1 - (rank(k) - 1) / (nRank - 1)); % 0.65 (lightest) -> 0 (darkest)
            else
                mix = 0;
            end
            colors(idx(k), :) = base{side} * (1 - mix) + [1 1 1] * mix;
        end
    end
    other = ~ismember(groups(:, 1), [0 1 2]);
    colors(other, :) = repmat([0 0 0], nnz(other), 1);
end

function c = filledColor(marker, color)
    % Line-only markers (x) cannot be filled
    if strcmp(marker, 'x')
        c = 'none';
    else
        c = color;
    end
end

function label = groupLabel(g)
    % g = [correctSide, vibFreq]
    if g(1) == 0
        label = 'Catch';
        return;
    end
    sideNames = {'Left', 'Right'};
    if g(1) == 1 || g(1) == 2
        side = sideNames{g(1)};
    else
        side = 'Trial';
    end
    label = sprintf('%s: %g Hz', side, g(2));
end

function showMessage(ax, msg, customPlotFig)
    cla(ax);
    text(ax, 0.5, 0.5, msg, 'HorizontalAlignment', 'center', 'FontSize', 14);
    if ~isempty(customPlotFig)
        drawnow;
    end
end
