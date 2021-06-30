function C = read_campaign_data(fileName)
    % create a clean up object to close file upon Ctrl+C
    cleanupObj = onCleanup(@cleanUp);
    %Open the data file
    % global fid;
    [fid, message] = fopen(fileName);
    if (fid==-1)
        error(['Unable to open data file ' fileName '!']);
    end
    %Set markers
    commentMarker='#';
    whitespaceMarker = char(0); % simply using ' ' does not work
    acqStartMarker='# Acquisition start: ';
    acqEndMarker='# Acquisition end: ';
    Nstart = 1;
    Nend = 1;
    Ndata =1;
    Nline = 1;
    
    read = 1;
    while read
        a = fgetl(fid);
        if a == -1
            read = 0; 
            break; 
        end
        if strncmp(a,acqStartMarker,length(acqStartMarker)) % Log Acquisition start times
            sCell = textscan(a,'%s %s %s %s %s');
            start_dtimes(Nstart) = datetime(strjoin([sCell{4} sCell{5}]));
            Nstart = Nstart+1;
        elseif strncmp(a,acqEndMarker,length(acqEndMarker)) % Log Acquisition endf times
            eCell = textscan(a,'%s %s %s %s %s');
            end_dtimes(Nend) = datetime(strjoin([eCell{4} eCell{5}]));
            Nend = Nend+1;
        elseif length(a)>=1
            if ~isnan(str2double(a(1))) % If the first character of the line is numeric: log data
                dCell = textscan(a,'%f %f');
                freq_data(Ndata) = dCell{1};
                mag_data(Ndata) = dCell{2};
                Ndata = Ndata+1;
            end
        end
        Nline = Nline+1;
    end
    disp(['Read a total of ',num2str(Nline),' lines'])
    fclose(fid);

    C.start_dtimes = start_dtimes;
    C.end_dtimes = end_dtimes;
    C.freq_data = freq_data;
    C.mag_data = mag_data;
    
    % fires when main function terminates
    function cleanUp()
        disp('Closing file on line: ',num2str(Nline));
        fclose('all');
    end
end
