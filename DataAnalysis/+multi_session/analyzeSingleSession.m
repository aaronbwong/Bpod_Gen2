function [sessionTable, sessionMetaTable] = analyzeSingleSession(currentSessionData, filename)
%analyzeSingleSession Analyze one session file from a loaded .mat struct.
%   [sessionTable, sessionMetaTable] = multi_session.analyzeSingleSession(currentSessionData, filename)
%   returns a per-stimulus session table and a one-row session metadata table.

if isstruct(currentSessionData) && isfield(currentSessionData, 'SessionData')
    SessionData = currentSessionData.SessionData;
else
    error('Could not find SessionData structure in loaded file.');
end
if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
    error('SessionData.RawEvents.Trial not found.');
end

nTrials = numel(SessionData.RawEvents.Trial);
[~, fileNameNoExt, ~] = fileparts(filename);
parts = strsplit(fileNameNoExt, '_');
if numel(parts) >= 4
    animalID = parts{1};
    protocol = parts{2};
    datetimeStr = [parts{3} '_' parts{4}];
else
    animalID = fileNameNoExt;
    protocol = '';
    datetimeStr = '';
end

GUI_settings = struct2table([SessionData.TrialSettings(:).GUI]);
GUI_settings = unique(GUI_settings, 'rows');
if height(GUI_settings) == 1
    sessionMetaTable = GUI_settings;
else
    MinITI = min(GUI_settings.MinITI);
    MaxITI = max(GUI_settings.MaxITI);
    MinQuietTime = min(GUI_settings.MinQuietTime);
    MaxQuietTime = max(GUI_settings.MaxQuietTime);
    RewardAmount = mean(GUI_settings.RewardAmount);
    ResWin = mean(GUI_settings.ResWin);
    CutOffPeriod = mean(GUI_settings.CutOffPeriod);
    sessionMetaTable = table(MinITI, MaxITI, MinQuietTime, MaxQuietTime, RewardAmount, ResWin, CutOffPeriod);
end
if ~ismember('NCorrectToSwitch', GUI_settings.Properties.VariableNames)
    sessionMetaTable.NCorrectToSwitch = nan(1);
elseif ~ismember('NCorrectToSwitch', sessionMetaTable.Properties.VariableNames)
    sessionMetaTable.NCorrectToSwitch = mean(GUI_settings.NCorrectToSwitch);
end

if ~isfield(SessionData, 'StimTable')
    assert(isfield(SessionData, 'CurrentSide') && isfield(SessionData, 'LeftRightSeq'), ...
        'Cannot rebuild StimTable: CurrentSide or LeftRightSeq missing.');
    currentSideArray = SessionData.CurrentSide;
    T1 = SessionData.LeftRightSeq.LowFreqTable;
    T2 = SessionData.LeftRightSeq.HighFreqTable;
    t1_row = 1;
    t2_row = 1;
    StimTable = table();
    for i = 1:numel(currentSideArray)
        if currentSideArray(i) == 1
            StimTable(i, :) = T1(t1_row, :);
            t1_row = t1_row + 1;
        elseif currentSideArray(i) == 2
            StimTable(i, :) = T2(t2_row, :);
            t2_row = t2_row + 1;
        end
    end
elseif nTrials ~= height(SessionData.StimTable)
    StimTable = SessionData.StimTable(1:nTrials, :);
else
    StimTable = SessionData.StimTable;
end

requiredVars = {'VibFreq', 'VibAmp'};
if ~all(ismember(requiredVars, StimTable.Properties.VariableNames))
    error('StimTable must contain VibFreq and VibAmp columns.');
end

vibFreqs = StimTable.VibFreq(:);
vibAmps = StimTable.VibAmp(:);

tol = 1e-6;
allCombos = [vibFreqs, vibAmps];
uniqueCombos = unique(allCombos, 'rows');
[~, sortIdx] = sortrows(uniqueCombos, [1 2]);
uniqueCombos = uniqueCombos(sortIdx, :);
nCombos = size(uniqueCombos, 1);

condCounts = zeros(nCombos, 3);
allRTsByCondition = cell(nCombos, 1);
allRTsLeftByCondition = cell(nCombos, 1);
allRTsRightByCondition = cell(nCombos, 1);
allRTsCatchByCondition = cell(nCombos, 1);
for t = 1:nTrials
    curFreq = vibFreqs(t);
    curAmp = vibAmps(t);
    if isnan(curFreq) || isnan(curAmp)
        continue;
    end
    [firstSide, response_latency] = multi_session.getFirstResponseSide(SessionData, t);
    idx = find(abs(uniqueCombos(:,1) - curFreq) < tol & abs(uniqueCombos(:,2) - curAmp) < tol, 1);
    if isempty(idx)
        continue;
    end
    condCounts(idx, 1) = condCounts(idx, 1) + 1;
    if firstSide == 1
        condCounts(idx, 2) = condCounts(idx, 2) + 1;
    elseif firstSide == 2
        condCounts(idx, 3) = condCounts(idx, 3) + 1;
    end
    if ~isnan(response_latency)
        allRTsByCondition{idx} = [allRTsByCondition{idx}, response_latency]; %#ok<AGROW>
        if curFreq == 0
            allRTsCatchByCondition{idx} = [allRTsCatchByCondition{idx}, response_latency]; %#ok<AGROW>
        elseif firstSide == 1
            allRTsLeftByCondition{idx} = [allRTsLeftByCondition{idx}, response_latency]; %#ok<AGROW>
        elseif firstSide == 2
            allRTsRightByCondition{idx} = [allRTsRightByCondition{idx}, response_latency]; %#ok<AGROW>
        end
    end
end

sessionTable = table();
sessionTable.VibFreq = zeros(nCombos, 1);
sessionTable.VibAmp = zeros(nCombos, 1);
sessionTable.NTrials = zeros(nCombos, 1);
sessionTable.LeftRes = zeros(nCombos, 1);
sessionTable.RightRes = zeros(nCombos, 1);
sessionTable.RT_Median = nan(nCombos, 1);
sessionTable.N_ValidRT = zeros(nCombos, 1);
sessionTable.ResponseLatenciesLeft = cell(nCombos, 1);
sessionTable.ResponseLatenciesRight = cell(nCombos, 1);
sessionTable.ResponseLatenciesCatch = cell(nCombos, 1);
for i = 1:nCombos
    sessionTable.VibFreq(i) = uniqueCombos(i, 1);
    sessionTable.VibAmp(i) = uniqueCombos(i, 2);
    sessionTable.NTrials(i) = condCounts(i, 1);
    sessionTable.LeftRes(i) = condCounts(i, 2);
    sessionTable.RightRes(i) = condCounts(i, 3);
    validRTs = allRTsByCondition{i};
    sessionTable.N_ValidRT(i) = numel(validRTs);
    if ~isempty(validRTs)
        sessionTable.RT_Median(i) = median(validRTs);
    end
    sessionTable.ResponseLatenciesLeft{i} = allRTsLeftByCondition{i};
    sessionTable.ResponseLatenciesRight{i} = allRTsRightByCondition{i};
    sessionTable.ResponseLatenciesCatch{i} = allRTsCatchByCondition{i};
end

sessionTable.FileName = repmat({filename}, nCombos, 1);
sessionTable.AnimalID = repmat({animalID}, nCombos, 1);
sessionTable.Protocol = repmat({protocol}, nCombos, 1);
sessionTable.Time = repmat({datetimeStr}, nCombos, 1);
sessionTable.Session_nTrials = repmat(nTrials, nCombos, 1);
sessionTable.ResWin = repmat(sessionMetaTable.ResWin, nCombos, 1);

sessionMetaTable.FileName = {filename};
sessionMetaTable.AnimalID = {animalID};
sessionMetaTable.Protocol = {protocol};
sessionMetaTable.Time = datetimeStr;
sessionMetaTable.Session_nTrials = nTrials;
sessionMetaTable = movevars(sessionMetaTable, {'FileName','AnimalID','Protocol','Time','Session_nTrials'}, 'Before', 1);


sessionTable.DateTime = datetime(sessionTable.Time, ...
    'InputFormat', 'yyyyMMdd_HHmmss');
sessionMetaTable.DateTime = datetime(sessionMetaTable.Time, ...
    'InputFormat', 'yyyyMMdd_HHmmss');
end
