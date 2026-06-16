function [resultsTable, metaTable] = analyzeFiles(selectedFiles)
%analyzeFiles Analyze multiple Bpod session .mat files.
%   [resultsTable, metaTable] = multi_session.analyzeFiles(selectedFiles)
%   loads each selected file and extracts per-stimulus and session meta
%   information using multi_session.analyzeSingleSession.

if nargin < 1 || isempty(selectedFiles)
    resultsTable = table();
    metaTable = table();
    return;
end
if ischar(selectedFiles)
    selectedFiles = {selectedFiles};
end

resultsTable = table();
metaTable = table();
for fileIdx = 1:numel(selectedFiles)
    absolutePath = selectedFiles{fileIdx};
    if ~exist(absolutePath, 'file')
        warning('File not found: %s. Skipping.', absolutePath);
        continue;
    end

    [~, nameOnly, extension] = fileparts(absolutePath);
    filename = [nameOnly, extension];
    fprintf('========================================\n');
    fprintf('Processing file %d of %d: %s\n', fileIdx, numel(selectedFiles), filename);
    fprintf('File path: %s\n', absolutePath);

    switch lower(extension)
        case '.mat'
            try
                currentSessionData = load(absolutePath);
                fprintf('MAT file loaded successfully\n');
            catch err
                warning('Failed to load %s: %s', absolutePath, err.message);
                continue;
            end
        otherwise
            warning('Unsupported file type: %s. Skipping this file.', extension);
            continue;
    end

    if isempty(fieldnames(currentSessionData))
        warning('Loaded file contains no variables: %s. Skipping.', filename);
        continue;
    end

    try
        [sessionTable, sessionMetaTable] = multi_session.analyzeSingleSession(currentSessionData, filename);
        sessionTable.FilePath = repmat({absolutePath}, height(sessionTable), 1);
        sessionTable = movevars(sessionTable, 'FilePath', 'Before', 'FileName');
        sessionMetaTable.FilePath = {absolutePath};
        sessionMetaTable = movevars(sessionMetaTable, 'FilePath', 'Before', 'FileName');
        
        % Harmonize and concatenate tables
        resultsTable = appendTables(resultsTable, sessionTable);
        metaTable = appendTables(metaTable, sessionMetaTable);
        fprintf('Current session analysed successfully\n');
    catch err
        warning('Analysis failed for %s: %s', filename, err.message);
        keyboard
    end
end
end

%% Local helper function
function tableOut = appendTables(table1, table2)
    %appendTables Append two tables, combining variables from both with stable order.
    %   tableOut = appendTables(table1, table2) combines variables from both tables,
    %   prioritizing table1's variables first (in their original order), then adds
    %   any additional variables from table2. Missing variables are filled with NaN.
    
    if isempty(table1); tableOut=table2;return;end
    if isempty(table2); tableOut=table1;return;end

    varNames1 = table1.Properties.VariableNames;
    varNames2 = table2.Properties.VariableNames;
    
    % Combine variable names: table1's vars first, then table2's unique vars (stable order)
    allVarNames = unique([varNames1,varNames2],'stable');%[varNames1, setdiff(varNames2, varNames1, 'stable')];
    
    % Add missing variables to table1
    for i = 1:length(allVarNames)
        varName = allVarNames{i};
        if ~ismember(varName, table1.Properties.VariableNames)
            table1.(varName) = nan(height(table1), 1);
        end
    end
    
    % Add missing variables to table2
    for i = 1:length(allVarNames)
        varName = allVarNames{i};
        if ~ismember(varName, table2.Properties.VariableNames)
            table2.(varName) = nan(height(table2), 1);
        end
    end
    
    % Reorder both tables to match combined column order
    table1 = table1(:, allVarNames);
    table2 = table2(:, allVarNames);
    tableOut = [table1; table2];
end
