function [psychTable, fitTable] = plotPsychometricByAnimal(T, varargin)
%plotPsychometricByAnimal Psychometric functions per animal, pooled across sessions.
%   [psychTable, fitTable] = multi_session.plotPsychometricByAnimal(T, ...)
%   T is the per-stimulus table from multi_session.analyzeFiles (or the
%   T output of analyseSessionResults) with AnimalID, VibFreq, VibAmp,
%   NTrials, LeftRes and RightRes. Counts are pooled over all sessions
%   (or the selected ones) for each animal and (VibFreq, VibAmp).
%
%   'Type'          'amplitude' (default): response rate = (L+R)/N vs amplitude,
%                   one curve per frequency; catch trials (VibFreq == 0) are
%                   drawn as amplitude 0 on every curve.
%                   'frequency': rate of choosing the spout rewarded for high
%                   frequencies, H/(L+R), vs frequency (using the per-session
%                   HighFreqSide 'left'/'right' from SessionData.StimParams.Behave,
%                   default right). Individual amplitudes are
%                   shown as unconnected points with a thick connected
%                   average per frequency on top; no legend; catch trials are excluded.
%   'Fit'           Weibull fit (binomial likelihood) for 'amplitude' type.
%                   Default true. Ignored for 'frequency'.
%   'BoundaryFreq'  Draw category boundary on 'frequency' plots. Default [].
%   'MinTrials'     Minimum pooled trials for a point to be shown. Default 1.
%   'Animals'       Animal ID(s) to include, e.g. {'Y001','Y003'}. Default all.
%   'Frequencies'   Frequencies (Hz) to include, e.g. [100 300]. Catch trials
%                   are always kept for the 'amplitude' type. Default all.
%   'PanelBy'       'condition': one subplot per frequency ('amplitude' type) or
%                   per amplitude ('frequency' type), one line per animal.
%                   'animal': one subplot per animal, one line per condition.
%                   Default 'condition' for 'amplitude', 'animal' for 'frequency'.
%   'Plot'          Default true.
%   'LinkAxes'      Link the x-axes of all panels for the 'frequency' type.
%                   Default true; set false for independent x-axes.
%   'PoolAnimals'   'frequency' type: draw all animals on a single panel, one
%                   connected line per animal (its rate per frequency, pooled
%                   over amplitudes, with a legend). Default false.
%   'SessionNumber','SessionDate','PeriodDays'  Session selection passed to
%                   multi_session.selectSessionsByAnimal. Without any of
%                   them all sessions are used.
%
%   psychTable has one row per animal/stimulus with Rate, CILow, CIHigh (95% Wilson).
%   fitTable has Weibull parameters per animal/frequency (empty if not fitted).

p = inputParser;
addRequired(p, 'T', @istable);
addParameter(p, 'Type', 'amplitude', @(x) any(strcmpi(x, {'amplitude','frequency'})));
addParameter(p, 'Fit', true, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'BoundaryFreq', [], @(x) isempty(x) || isscalar(x));
addParameter(p, 'MinTrials', 1, @isscalar);
addParameter(p, 'Animals', {}, @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'Frequencies', [], @isnumeric);
addParameter(p, 'PanelBy', '', @(x) isempty(x) || any(strcmpi(x, {'condition','animal'})));
addParameter(p, 'Plot', true, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'LinkAxes', true, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'PoolAnimals', false, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'SessionNumber', [], @(x) isempty(x) || isscalar(x));
addParameter(p, 'SessionDate', [], @(x) isempty(x) || isdatetime(x) || ischar(x) || isstring(x));
addParameter(p, 'PeriodDays', [], @(x) isempty(x) || isscalar(x));
parse(p, T, varargin{:});
r = p.Results;
type = lower(r.Type);

if ~all(ismember({'AnimalID','VibFreq','VibAmp','NTrials','LeftRes','RightRes'}, T.Properties.VariableNames))
    error('Table must contain AnimalID, VibFreq, VibAmp, NTrials, LeftRes, and RightRes fields.');
end

if ~isempty(r.SessionNumber) || ~isempty(r.SessionDate) || ~isempty(r.PeriodDays)
    args = {};
    if ~isempty(r.SessionNumber), args = [args, {'SessionNumber', r.SessionNumber}]; end
    if ~isempty(r.SessionDate),   args = [args, {'SessionDate', r.SessionDate}]; end
    if ~isempty(r.PeriodDays),    args = [args, {'PeriodDays', r.PeriodDays}]; end
    T = multi_session.selectSessionsByAnimal(T, args{:});
end
if ~isempty(r.Animals)
    keepAnimals = cellstr(r.Animals);
    missing = setdiff(keepAnimals, unique(T.AnimalID));
    if ~isempty(missing)
        warning('Animals not found: %s', strjoin(missing, ', '));
    end
    T = T(ismember(T.AnimalID, keepAnimals), :);
end
if ~isempty(r.Frequencies)
    keepRows = ismember(T.VibFreq, r.Frequencies);
    if strcmp(type, 'amplitude')
        keepRows = keepRows | T.VibFreq == 0;
    end
    T = T(keepRows, :);
end
if isempty(T)
    warning('No records found using the selected criteria.');
    psychTable = table(); fitTable = table();
    return;
end

% Pool counts across sessions. Choices are expressed relative to the side
% rewarded for high frequencies (HighFreqSide: 'left' or 'right'; default right).
if ismember('HighFreqSide', T.Properties.VariableNames)
    highIsLeft = strcmpi(T.HighFreqSide, 'left');
else
    highIsLeft = false(height(T), 1);
end
T.HighRes = T.RightRes;
T.HighRes(highIsLeft) = T.LeftRes(highIsLeft);
G = varfun(@sum, T, 'InputVariables', {'NTrials','LeftRes','RightRes','HighRes'}, ...
    'GroupingVariables', {'AnimalID','VibFreq','VibAmp'});
G.Properties.VariableNames = strrep(G.Properties.VariableNames, 'sum_', '');
G.GroupCount = [];
G = sortrows(G, {'AnimalID','VibFreq','VibAmp'});
animals = unique(G.AnimalID, 'stable');

if strcmp(type, 'amplitude')
    psychTable = buildAmplitudeTable(G);
else
    G = G(G.VibFreq ~= 0, :);
    psychTable = G;
    psychTable.NResp = G.LeftRes + G.RightRes;
    psychTable.NTotal = psychTable.NResp;
    psychTable.Successes = G.HighRes;
end
psychTable = psychTable(psychTable.NTotal >= r.MinTrials & psychTable.NTotal > 0, :);
[psychTable.Rate, psychTable.CILow, psychTable.CIHigh] = ...
    wilson(psychTable.Successes, psychTable.NTotal);

fitTable = table();
if strcmp(type, 'amplitude') && r.Fit
    fitTable = fitWeibull(psychTable);
end

if r.Plot
    panelBy = lower(r.PanelBy);
    if isempty(panelBy)
        panelBy = 'condition';
        if strcmp(type, 'frequency'), panelBy = 'animal'; end
    end
    if strcmp(type, 'frequency') && r.PoolAnimals
        plotAnimalsOnePanel(psychTable, animals, r.BoundaryFreq);
    else
        plotAll(psychTable, fitTable, animals, type, r.BoundaryFreq, panelBy, logical(r.LinkAxes));
    end
end
end

function plotAnimalsOnePanel(P, animals, boundaryFreq)
figure('Position', [100, 100, 600, 450]);
ax = axes; hold(ax, 'on');
cols = lines(max(numel(animals), 1));
h = gobjects(0); names = {};
for g = 1:numel(animals)
    mA = strcmp(P.AnimalID, animals{g});
    if ~any(mA), continue; end
    fr = unique(P.VibFreq(mA));
    rate = nan(size(fr));
    for k = 1:numel(fr)
        mF = mA & P.VibFreq == fr(k);
        rate(k) = sum(P.Successes(mF)) / sum(P.NTotal(mF));
    end
    h(end+1) = plot(ax, fr, rate, 'o-', 'Color', cols(g, :), ...
        'MarkerFaceColor', cols(g, :), 'MarkerSize', 6, 'LineWidth', 2); %#ok<AGROW>
    names{end+1} = animals{g}; %#ok<AGROW>
end
yline(ax, 0.5, ':k', 'HandleVisibility', 'off');
if ~isempty(boundaryFreq)
    xline(ax, boundaryFreq, ':k', 'HandleVisibility', 'off');
end
xlabel(ax, 'Frequency (Hz)'); ylabel(ax, 'P(high-freq side | response)');
ylim(ax, [0 1]); grid(ax, 'on');
title(ax, 'Psychometric function: high-frequency-side rate vs frequency');
if ~isempty(h)
    legend(ax, h, names, 'Location', 'best', 'FontSize', 8);
end
end

function P = buildAmplitudeTable(G)
% Catch rows (VibFreq == 0) become amplitude 0 for every frequency of that animal
P = table();
animals = unique(G.AnimalID, 'stable');
for i = 1:numel(animals)
    Ga = G(strcmp(G.AnimalID, animals{i}), :);
    catchRow = Ga(Ga.VibFreq == 0, :);
    Ga = Ga(Ga.VibFreq ~= 0, :);
    freqs = unique(Ga.VibFreq);
    for f = freqs(:)'
        Gf = Ga(Ga.VibFreq == f, :);
        if ~isempty(catchRow)
            c = catchRow;
            c.VibFreq(:) = f;
            c.VibAmp(:) = 0;
            Gf = [c; Gf]; %#ok<AGROW>
        end
        P = [P; Gf]; %#ok<AGROW>
    end
end
P.NResp = P.LeftRes + P.RightRes;
P.NTotal = P.NTrials;
P.Successes = P.NResp;
end

function [rate, lo, hi] = wilson(k, n)
    % Wilson score interval for binomial proportion (Wilson, E.B., 1927)
    % k: number of successes, n: number of trials
    % rate: estimated proportion, lo: lower bound, hi: upper bound
z = 1.96; % critical value for 95% confidence interval (standard normal distribution)
rate = k ./ n;
den = 1 + z^2 ./ n;
ctr = (rate + z^2 ./ (2*n)) ./ den;
hw = z * sqrt(rate .* (1 - rate) ./ n + z^2 ./ (4*n.^2)) ./ den;
lo = max(ctr - hw, 0);
hi = min(ctr + hw, 1);
end

function fitTable = fitWeibull(P)
% Weibull with guess/lapse: g + (1-g-l)*(1-exp(-(x/thr)^slope)), binomial likelihood
model = @(q, x) q(1) + (1 - q(1) - q(2)) * (1 - exp(-(x ./ q(4)).^q(3)));
rows = {};
combos = unique(P(:, {'AnimalID','VibFreq'}), 'rows');
for i = 1:height(combos)
    m = strcmp(P.AnimalID, combos.AnimalID{i}) & P.VibFreq == combos.VibFreq(i);
    x = P.VibAmp(m); k = P.Successes(m); n = P.NTotal(m);
    pos = x(x > 0);
    if numel(unique(x)) < 3 || isempty(pos)
        continue;
    end
    nll = @(q) -sum(k .* log(max(model(q, x), eps)) + (n - k) .* log(max(1 - model(q, x), eps)));
    q0 = [0.05, 0.05, 2, median(pos)];
    lb = [0, 0, 0.1, min(pos)/10];
    ub = [1, 0.5, 20, max(pos)*2];
    try
        % fminsearch (base MATLAB) with a penalty for leaving the bounds
        bounded = @(q) nll(min(max(q, lb), ub)) + 1e3 * sum((q - min(max(q, lb), ub)).^2);
        q = fminsearch(bounded, q0, optimset('Display', 'off', 'MaxFunEvals', 4000, 'MaxIter', 4000));
        q = min(max(q, lb), ub);
    catch err
        warning('Fit failed for %s @ %g Hz: %s', combos.AnimalID{i}, combos.VibFreq(i), err.message);
        continue;
    end
    rows(end+1, :) = {combos.AnimalID{i}, combos.VibFreq(i), q(4), q(3), q(1), q(2)}; %#ok<AGROW>
end
if isempty(rows)
    fitTable = table();
else
    fitTable = cell2table(rows, 'VariableNames', ...
        {'AnimalID','VibFreq','Threshold','Slope','GuessRate','LapseRate'});
end
end

function plotAll(P, fitTable, animals, type, boundaryFreq, panelBy, linkAxes)
model = @(q, x) q(1) + (1 - q(1) - q(2)) * (1 - exp(-(x ./ q(4)).^q(3)));
isAmp = strcmp(type, 'amplitude');
if isAmp
    xCol = 'VibAmp'; condCol = 'VibFreq'; condFmt = '%g Hz';
else
    xCol = 'VibFreq'; condCol = 'VibAmp'; condFmt = 'amp %.3g';
end
conds = unique(P.(condCol));

% Panels: one per animal or one per condition; lines: the other one
if strcmp(panelBy, 'animal')
    nP = numel(animals);
else
    nP = numel(conds);
end
nCols = min(max(ceil(sqrt(nP)), 1), 4);
nRows = ceil(nP / nCols);
figure('Position', [100, 100, 350*nCols + 100, 300*nRows + 100]);
animalColors = lines(max(numel(animals), 1));
condColors = lines(max(numel(conds), 1));
ptStyle = 'o-';
if ~isAmp, ptStyle = 'o'; end
axList = gobjects(0);

for i = 1:nP
    ax = subplot(nRows, nCols, i); hold(ax, 'on');
    axList(end+1) = ax; %#ok<AGROW>
    if strcmp(panelBy, 'animal')
        lineKeys = conds; panelTitle = sprintf('Animal: %s', animals{i});
    else
        lineKeys = animals; panelTitle = sprintf(condFmt, conds(i));
    end
    h = gobjects(0); names = {};
    for g = 1:numel(lineKeys)
        if strcmp(panelBy, 'animal')
            a = animals{i}; c = conds(g); col = condColors(g, :);
            name = sprintf(condFmt, c);
        else
            a = animals{g}; c = conds(i); col = animalColors(g, :);
            name = a;
        end
        m = strcmp(P.AnimalID, a) & P.(condCol) == c;
        if ~any(m), continue; end
        [x, o] = sort(P.(xCol)(m));
        y = P.Rate(m); y = y(o);
        lo = P.CILow(m); lo = lo(o);
        hi = P.CIHigh(m); hi = hi(o);
        h(end+1) = errorbar(ax, x, y, y - lo, hi - y, ptStyle, 'Color', col, ...
            'MarkerFaceColor', col, 'MarkerSize', 4, 'LineWidth', 1.2); %#ok<AGROW>
        names{end+1} = name; %#ok<AGROW>
        if isAmp && ~isempty(fitTable)
            fm = strcmp(fitTable.AnimalID, a) & fitTable.VibFreq == c;
            if any(fm)
                q = [fitTable.GuessRate(fm), fitTable.LapseRate(fm), fitTable.Slope(fm), fitTable.Threshold(fm)];
                xx = linspace(0, max(x), 100);
                plot(ax, xx, model(q, xx), '--', 'Color', col, 'HandleVisibility', 'off');
            end
        end
    end
    if ~isAmp
        % Average rate per animal and frequency (pooled over amplitudes), connected
        for g = 1:numel(animals)
            if strcmp(panelBy, 'animal')
                if g ~= i, continue; end
                avgCol = 'k';
            else
                avgCol = animalColors(g, :);
            end
            mA = strcmp(P.AnimalID, animals{g});
            if ~any(mA), continue; end
            fr = unique(P.VibFreq(mA));
            avgRate = nan(size(fr));
            for k = 1:numel(fr)
                mF = mA & P.VibFreq == fr(k);
                avgRate(k) = sum(P.Successes(mF)) / sum(P.NTotal(mF));
            end
            plot(ax, fr, avgRate, 'o-', 'Color', avgCol, 'MarkerFaceColor', avgCol, ...
                'MarkerSize', 6, 'LineWidth', 2.5, 'HandleVisibility', 'off');
        end
        yline(ax, 0.5, ':k', 'HandleVisibility', 'off');
        if ~isempty(boundaryFreq)
            xline(ax, boundaryFreq, ':k', 'HandleVisibility', 'off');
        end
        xlabel(ax, 'Frequency (Hz)'); ylabel(ax, 'P(high-freq side | response)');
    else
        xlabel(ax, 'Amplitude'); ylabel(ax, 'Response rate');
    end
    ylim(ax, [0 1]); grid(ax, 'on');
    title(ax, panelTitle);
    if isAmp && ~isempty(h)
        legend(ax, h, names, 'Location', 'best', 'FontSize', 8);
    end
end
if ~isAmp && linkAxes && numel(axList) > 1
    linkaxes(axList, 'x');
    fr = unique(P.VibFreq);
    if numel(fr) > 1
        pad = 0.05 * (max(fr) - min(fr));
        xlim(axList(1), [min(fr) - pad, max(fr) + pad]);
    end
end
if isAmp
    sgtitle('Psychometric function: response rate vs amplitude');
else
    sgtitle('Psychometric function: high-frequency-side rate vs frequency');
end
end

