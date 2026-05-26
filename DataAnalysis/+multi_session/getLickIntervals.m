function lickIntervals = getLickIntervals(SessionData)
%getLickIntervals Extract lick intervals from SessionData.
%   lickIntervals = multi_session.getLickIntervals(SessionData)
%   returns the time difference between consecutive lick events,
%   using trial start timestamps to convert relative lick times to
%   absolute session time.

if ~isstruct(SessionData) || ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')
    error('SessionData.RawEvents.Trial not found.');
end

nTrials = numel(SessionData.RawEvents.Trial);
if nTrials == 0
    lickIntervals = [];
    return;
end

if ~isfield(SessionData, 'TrialStartTimestamp')
    error('SessionData.TrialStartTimestamp is required to compute absolute lick times.');
end

trialStartTimes = SessionData.TrialStartTimestamp;
allLickTimes = [];
for trialIdx = 1:nTrials
    if trialIdx > numel(SessionData.RawEvents.Trial)
        continue;
    end
    trialData = SessionData.RawEvents.Trial{trialIdx};
    if trialIdx > numel(trialStartTimes) || isnan(trialStartTimes(trialIdx))
        continue;
    end
    trialStartTime = trialStartTimes(trialIdx);

    trialLickTimes = [];
    if isfield(trialData, 'Events')
        if isfield(trialData.Events, 'BNC1High')
            trialLickTimes = [trialLickTimes, trialData.Events.BNC1High];
        end
        if isfield(trialData.Events, 'BNC2High')
            trialLickTimes = [trialLickTimes, trialData.Events.BNC2High];
        end
    end

    if ~isempty(trialLickTimes)
        absoluteLickTimes = trialStartTime + trialLickTimes;
        allLickTimes = [allLickTimes, absoluteLickTimes]; %#ok<AGROW>
    end
end

if numel(allLickTimes) < 2
    lickIntervals = [];
    return;
end

allLickTimes = sort(allLickTimes);
lickIntervals = diff(allLickTimes);
end