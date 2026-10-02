function PlotCDFHitRate(SessionData, varargin)
    % PlotCDFHitRate - Plot CDF histogram of reaction time for hits in response window
    % 
    % This function plots the cumulative distribution function (CDF) of reaction times
    % for hits within the response window. X-axis represents reaction time (0 to ResWin),
    % Y-axis represents cumulative proportion of hits.
    %
    % Input:
    %   SessionData - Bpod session data structure
    %   varargin - Optional name-value pairs:
    %     'FigureHandle' - figure handle for the combined plot (optional, for activation in online mode)
    %     'Axes' - axes handle for the plot (optional, if not provided, creates new figure)
    %     'FigureName' - name for new figure if axes not provided (default: 'CDF of Hit Rate')
    %
    % Output:
    %   None
    %
    % Usage:
    %   Online mode: PlotCDFHitRate(SessionData, 'FigureHandle', customPlotFig, 'Axes', cdfAx);
    %   Offline mode: PlotCDFHitRate(SessionData);

    % Parse optional inputs
    p = inputParser;
    addParameter(p, 'FigureHandle', [], @(x) isempty(x) || isgraphics(x, 'figure'));
    addParameter(p, 'Axes', [], @(x) isempty(x) || isgraphics(x, 'axes'));
    addParameter(p, 'FigureName', 'CDF of Hit Rate', @ischar);
    parse(p, varargin{:});
    
    customPlotFig = p.Results.FigureHandle;
    ax = p.Results.Axes;
    figureName = p.Results.FigureName;
    
    % Activate figure if provided (for online mode)
    if ~isempty(customPlotFig) && isvalid(customPlotFig)
        figure(customPlotFig);
    end
    
    % Create axes if not provided (offline mode)
    if isempty(ax)
        figure('Name', figureName, 'Position', [100 100 1000 600]);
        ax = axes('Position', [0.1 0.15 0.85 0.75]);
    end
    
    % Check if data exists
    if ~isfield(SessionData, 'RawEvents') || ~isfield(SessionData.RawEvents, 'Trial')  
        warning('SessionData.RawEvents.Trial not found');
        cla(ax);
        text(ax, 0.5, 0.5, 'No data available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
        if ~isempty(customPlotFig)
            drawnow;
        end
        return;
    end
    
    % Get number of trials
    nTrials = length(SessionData.RawEvents.Trial);
    
    % Check if there are any trials
    if nTrials == 0
        warning('No trials found in SessionData');
        cla(ax);
        text(ax, 0.5, 0.5, 'No trials available', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
        if ~isempty(customPlotFig)
            drawnow;
        end
        return;
    end
    
    % Extract trial information
    if isfield(SessionData,"IsCatchTrial")
        isCatchTrial = SessionData.IsCatchTrial(1:nTrials) == 1;
    else
        isCatchTrial = false(nTrials, 1);
    end
    correctSide  = SessionData.CorrectSide(1:nTrials);
    isLeftTrial  = (correctSide == 1 ) & ~ isCatchTrial;
    isRightTrial = (correctSide == 2 ) & ~ isCatchTrial;

    % Count total trials for each condition
    nLeftTrials  = sum(isLeftTrial);
    nRightTrials = sum(isRightTrial);
    nCatchTrials = sum(isCatchTrial);

    % Get maximum ResWin for x-axis range
    if isfield(SessionData, 'ResWin')
        maxResWin = max(SessionData.ResWin);
    else
        maxResWin = 1; % Default if ResWin not available
    end
    
    reactionTimes = Inf(nTrials, 1);

    for trialNum = 1:nTrials
        if trialNum > length(SessionData.RawEvents.Trial)
            break;
        end
        % Get trial data
        trialData = SessionData.RawEvents.Trial{trialNum};
                
        stimulusStart = trialData.States.Stimulus(1);
        
        licksTimes = [];
        if isfield(trialData.Events, 'BNC1High')
            licksTimes = [licksTimes,trialData.Events.BNC1High];
        end
        if isfield(trialData.Events, 'BNC2High')
            licksTimes = [licksTimes,trialData.Events.BNC2High];
        end
        if any(licksTimes>stimulusStart)
            reactionTimes(trialNum) = min(licksTimes(licksTimes>stimulusStart)-stimulusStart);
        end        
        
    end

    if nLeftTrials > 0; leftReactionTimes = reactionTimes(isLeftTrial); else; leftReactionTimes = []; end
    if nRightTrials > 0; rightReactionTimes = reactionTimes(isRightTrial); else; rightReactionTimes = []; end
    if nCatchTrials > 0; catchReactionTimes = reactionTimes(isCatchTrial); else; catchReactionTimes = []; end


    % Plot CDF histogram
    axes(ax);
    cla(ax);
    hold(ax, 'on');
    
    % Plot CDF as step function (histogram style)
    if nLeftTrials > 0
        leftCDF_x = min([0;sort(leftReactionTimes)],maxResWin+0.1);
        leftCDF_y = (0:nLeftTrials)./nLeftTrials;
        stairs(ax, leftCDF_x, leftCDF_y, 'b-', 'LineWidth', 2, 'DisplayName', 'Left');
    end
    
    if nRightTrials > 0
        rightCDF_x = min([0;sort(rightReactionTimes)],maxResWin+0.1);
        rightCDF_y = (0:nRightTrials)./nRightTrials;
        stairs(ax, rightCDF_x, rightCDF_y, 'r-', 'LineWidth', 2, 'DisplayName', 'Right');
    end
    
    if nCatchTrials > 0
        catchCDF_x = min([0;sort(catchReactionTimes)],maxResWin+0.1);
        catchCDF_y = (0:nCatchTrials)./nCatchTrials;
        stairs(ax, catchCDF_x, catchCDF_y, 'g-', 'LineWidth', 2, 'DisplayName', 'Catch');
    end
    
    % Formatting
    xlabel(ax, 'Reaction Time (seconds from stimulus start)');
    ylabel(ax, 'Cumulative proportion of all trials');
    title(ax, 'CDF of All Reaction Times');
    legend(ax, 'Location', 'northwest');
    grid(ax, 'on');
    ylim(ax, [0 1]);
    xlim(ax, [0 maxResWin]);
    
    hold(ax, 'off');
    
    % Force update of the figure (for online mode)
    if ~isempty(customPlotFig)
        drawnow;
    end