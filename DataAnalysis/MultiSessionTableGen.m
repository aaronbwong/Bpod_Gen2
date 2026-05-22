%% Multi-session table generation
% Select session file paths, then run analysis on the selected files.
load('DEFAULT_FILE_PATHS.mat','DEFAULT_DATA_FOLDER')
selectedFiles = multi_session.selectSubjectFolders(DEFAULT_DATA_FOLDER);
if isempty(selectedFiles)
    disp('No files selected. Exiting.');
    return;
end
%%
[resultsTable, metaTable] = multi_session.analyzeFiles(selectedFiles);

disp('Multi-session analysis complete.');
