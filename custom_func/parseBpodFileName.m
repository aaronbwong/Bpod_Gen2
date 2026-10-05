function [subjectStr,protocolStr,dateTimeStr] = parseBpodFileName(bpodFileName)
%parseBpodFileName 

    pat = '([a-zA-Z0-9]+)_(\w+)_([\d]{8}_[\d]{6})';
    [out] = regexp(bpodFileName,pat,'tokens');

    if ~isempty(out)
        out = out{1};
        [subjectStr,protocolStr,dateTimeStr] = out{:};
    end
end