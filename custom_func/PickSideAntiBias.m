% PickSideAntiBias function
% This function is used to decide which side the animal should be trained on in the next trial
% based on anti-bias logic (favor the side with lower hit rate)
% Input: SessionData - the session data
% Output: nextTrialSide - the spout side for the next trial (1=left, 2=right)
% Note: The return value is a spout (left/right), not a frequency side (low/high freq)
% The caller (AntiBias.m) will convert this to frequency side based on configuration
function nextTrialSide = PickSideAntiBias(SessionData)
    
    runningAvg = 10;
    maxConsec = 3; % Maximum number of consecutive same side trials
   
    % If there are less than 2 * runningAvg trials, set probability to 0.5
    % and choose randomly, but not more than maxConsec consecutive same side trials
    totalTrials = length(SessionData.CorrectSide);

    %% 1: Check maxConsec condition ============
    if totalTrials >= maxConsec
        recentSides = SessionData.CorrectSide((totalTrials - maxConsec + 1):totalTrials);
        % Check if all recent sides are the same
        if all(recentSides == recentSides(1))
            % Force switch to opposite side
            nextTrialSide = 3 - recentSides(1);
            return;
        end
    end

    %% 2: Check enough for running average ===============
    if totalTrials < 2 * runningAvg
        % Choose randomly if not maxConsec consecutive same side
        probL = 0.5;
        nextTrialSide = 2 - (rand() < probL);
        return;
    end

    %% 3: Calculate Hit Rates and Pick a side

    % Determine if trials are correct, if not already done in protocol.
    if ~isfield(SessionData,'IsCorrect')
        SessionData.IsCorrect = nan(1,totalTrials);
        for trialNum = 1:totalTrials
            SessionData.IsCorrect(trialNum) = checkCorrect(SessionData,trialNum);
        end
    end

    % After 2 * runningAvg trials, calculate the probability of selecting left spout based on anti-bias logic
    leftNonCatchTrials = find(SessionData.CorrectSide(:) == 1 & ~SessionData.IsCatchTrial(:),...
                               runningAvg, 'last');
    rightNonCatchTrials = find(SessionData.CorrectSide(:) == 2 & ~SessionData.IsCatchTrial(:),...
                               runningAvg, 'last');
    % StartTrialNum = max(1, totalTrials - runningAvg + 1); % Ensure StartTrialNum >= 1

    % Loop through recent Left trials (last runningAvg trials)
    NumLeftNonCatchTrials = length(leftNonCatchTrials);
    leftHits = sum(SessionData.IsCorrect(leftNonCatchTrials));
    leftHitRate = leftHits / NumLeftNonCatchTrials;

    % Loop through recent Right trials (last runningAvg trials)
    NumRightNonCatchTrials = length(rightNonCatchTrials);
    rightHits = sum(SessionData.IsCorrect(rightNonCatchTrials));
    rightHitRate = rightHits / NumRightNonCatchTrials;

    % Calculate probability of selecting left spout based on anti-bias logic
    % Formula: probL = (rightHitRate + (1 - leftHitRate)) / 2
    % This ensures:
    % - If right side performs well (high rightHitRate), increase prob of left (bias correction)
    % - If left side performs poorly (low leftHitRate), increase prob of left (bias correction)
    % - If both sides equal (0.5 each), probL = 0.5 (balanced)
    % Range: probL is always between 0 and 1
    probL = (rightHitRate + (1 - leftHitRate)) / 2;

    % Generate next trial side (1=left spout, 2=right spout)
    if rand() < probL
        nextTrialSide = 1; % Left spout
    else
        nextTrialSide = 2; % Right spout
    end
end

% Function to check if a reward was triggered by Port1
function triggered = isTriggered(trialData)

    if isfield(trialData.Events, 'Condition6') % hopefully not NaN.
        triggered = true;
    else
        triggered = false;
    end
end

function isCorrect = checkCorrect(SessionData, currentTrial)
    isCorrect = false;
    if SessionData.IsCatchTrial(currentTrial)
        % catch trials (always correct?)
        isCorrect = true; % Catch trials are excluded from response scoring
    elseif ismember({'Condition6'}, fieldnames(SessionData.RawEvents.Trial{currentTrial}.Events))
        % manual reward
    elseif any(ismember({'LeftReward', 'RightReward'}, fieldnames(SessionData.RawEvents.Trial{currentTrial}.States)))
        if any(~isnan(SessionData.RawEvents.Trial{currentTrial}.States.LeftReward)) || ...
                any(~isnan(SessionData.RawEvents.Trial{currentTrial}.States.RightReward)) 
            % rewarded i.e. correct
            isCorrect = true;
        end
    else
        % miss
    end

end