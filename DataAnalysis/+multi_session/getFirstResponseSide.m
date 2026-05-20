function [firstSide, response_latency] = getFirstResponseSide(SessionData, trialIdx)
%getFirstResponseSide Determine the first response side for one trial.
%   [firstSide, response_latency] = multi_session.getFirstResponseSide(SessionData, trialIdx)
%   returns 1 for left, 2 for right, and NaN if no valid response is detected.

firstSide = NaN;
response_latency = NaN;
tr = SessionData.RawEvents.Trial{trialIdx};
if ~isfield(tr, 'Events')
    return;
end

if isfield(SessionData, 'ResWin')
    resWin = SessionData.ResWin(trialIdx);
else
    resWin = 5;
end

if isfield(tr.Events, 'HiFi1_1')
    stimOn = tr.Events.HiFi1_1;
elseif isfield(tr.Events, 'GlobalTimer2_Start')
    stimOn = tr.Events.GlobalTimer2_Start;
else
    return;
end

leftFirst = [];
rightFirst = [];
if isfield(tr.Events, 'BNC1High') && ~isempty(tr.Events.BNC1High)
    leftTimes = tr.Events.BNC1High(:) - stimOn;
    leftTimes = leftTimes(leftTimes > 0 & leftTimes < resWin);
    if ~isempty(leftTimes)
        leftFirst = min(leftTimes);
    end
end
if isfield(tr.Events, 'BNC2High') && ~isempty(tr.Events.BNC2High)
    rightTimes = tr.Events.BNC2High(:) - stimOn;
    rightTimes = rightTimes(rightTimes > 0 & rightTimes < resWin);
    if ~isempty(rightTimes)
        rightFirst = min(rightTimes);
    end
end

if ~isempty(leftFirst) && ~isempty(rightFirst)
    if leftFirst <= rightFirst
        firstSide = 1;
        response_latency = leftFirst;
    else
        firstSide = 2;
        response_latency = rightFirst;
    end
elseif ~isempty(leftFirst)
    firstSide = 1;
    response_latency = leftFirst;
elseif ~isempty(rightFirst)
    firstSide = 2;
    response_latency = rightFirst;
end
end
