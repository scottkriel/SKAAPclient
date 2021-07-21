function C = read_magFull(fileName)
    % create a clean up object to close file upon Ctrl+C
    cleanupObj = onCleanup(@cleanUp);
    %Open the data file
    % global fid;
    [fid, message] = fopen(fileName);
    if (fid==-1)
        error(['Unable to open data file ' fileName '!']);
    end
    %Set markers
    Ndata =1;
    Nline = 1;
    read = 1;
    while read
        a = fgetl(fid);
        if a == -1
            read = 0; 
            break; 
        end       
        if length(a)>=1 && ~isnan(str2double(a(2))) % If the first character of the line is numeric: log data
            C(Ndata,:) = str2double(split(a,' '));
            Ndata = Ndata+1;
        end
        Nline = Nline+1;
    end
    fclose(fid);
    
    % fires when main function terminates
    function cleanUp()
        fclose('all');
    end
end
