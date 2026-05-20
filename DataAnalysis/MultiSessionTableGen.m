%% Multi-session table generation
% Select session file paths, then run analysis on the selected files.
clearvars

selectedFiles = multi_session.selectFiles();
if isempty(selectedFiles)
    disp('No files selected. Exiting.');
    return;
end
%%
[resultsTable, metaTable] = multi_session.analyzeFiles(selectedFiles);

disp('Multi-session analysis complete.');
