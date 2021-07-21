classdef SKAAPclient
    
    properties
        % dirStruct
        serverDir(1,:) char      % Directory of the code files on SKAAP
        clientDir(1,:) char    % Working Directory of client 
        campaignDir(1,:) char    % Directory on client where campaign results are stored 
        ssh_struct                % structure containing SSH connection info       
    end
    
    properties (Constant = true)
        hostname='146.232.220.129';
        username='pi';
        password='skaap123'; 
    end
    
    properties (SetAccess = private)
        % Store the state the object is currently in
        STATUS = struct('running',0,'paused',0,'extFlag',NaN,'Nsweep',NaN,'start_time', NaN,'curr_time',NaN,'PID',NaN); 
        CTRL = struct('run',1,'pause',0,'quit',0);
    end
    
    methods
        %% Constructor
        function obj = SKAAPclient()
            % Handle different path slash character for Windows and Unix
            if ispc
                slash = '\';
            else
                slash = '/';
            end
            % Setup directory paths
            p = mfilename('fullpath');
            thisDir = fileparts(p);
            obj.clientDir = [thisDir,slash];
            obj.serverDir = '$HOME/SKAAP/SKAAPserver/';
            obj.campaignDir = [obj.clientDir,'campaign',slash];            
        end        

        function obj = init(obj)
            % Initialize SSH connection and display info
            obj = obj.open_connection();
            obj.get_status;
        end
        
        function obj = open_connection(obj)
        % Configure the ssh connection
            obj.ssh_struct = ssh2_config(obj.hostname,obj.username,obj.password);
            % Authenticate connection
            try
                obj.ssh_struct = ssh2(obj.ssh_struct);
                if obj.ssh_struct.authenticated
                    disp(['Connected to: ',obj.username,'@',obj.hostname])
                end
            catch
                error('Error: Could not connect to: "%s@%s"!',...
                obj.username,obj.hostname);
            end
        end

        function obj = close_connection(obj)
            obj.ssh_struct = ssh2_close(obj.ssh_struct);
        end
        
        function obj = get_status(obj)
            % Get server status 
            command=sprintf('cd %scampaign; echo "$(cat status.txt)"',obj.serverDir);
            % Execute command over ssh and retrieve response
            command_result = ssh2_command_response(ssh2_command(obj.ssh_struct, command, 1));  
            contents = command_result{1};
            if isempty(contents)
                disp('Server status file does not exist')
            else
                % Decode from json to struct
                S = jsondecode(contents);
                 % Convert to python dictionary structure
                STATUSdict=py.dict(S);
                % Write to file 
                fileID = fopen([obj.campaignDir,'status.txt'],'w');
                fprintf(fileID,'%s\n',STATUSdict);
                fclose(fileID);
                % Convert string times to datetime object
                S.curr_time=datetime(S.curr_time);
                S.start_time=datetime(S.start_time);
                obj.STATUS = S;
               
                if obj.STATUS.running
                    if obj.STATUS.paused
                        disp(['Campaign paused on sweep number ',num2str(obj.STATUS.Nsweep)])
                    else
                        disp(['Campaign running sweep number ',num2str(obj.STATUS.Nsweep+1)])
                    end
                else
                    if obj.STATUS.extFlag==-1
                        disp(['Previous campaign exited with error on sweep number ',num2str(obj.STATUS.Nsweep+1)])
                    elseif obj.STATUS.extFlag==0
                        disp(['Previous campaign terminated by user on sweep number ',num2str(obj.STATUS.Nsweep)])
                    elseif obj.STATUS.extFlag==obj.STATUS.Nsweep
                        disp(['Previous campaign finished running a total of ',num2str(obj.STATUS.Nsweep),' sweeps'])
                    else
                        disp('Unknown termination behaviour')
                    end
                end
            end
        end
        
        function [temp, humidity] = temp_humidity(obj)
            % Retrieve ambient temperature and humidity inside receiver box
            command=sprintf('cd %s; python3 temp_humidity.py',obj.serverDir);
            % Execute command over ssh and retrieve response
            command_result = ssh2_command_response(ssh2_command(obj.ssh_struct, command, 0));
            temp = str2double(command_result{1});
            humidity = str2double(command_result{2});
        end
        
        function devices = detect_devices(obj)
            % Detect connected SDR devices      
            % Build command to send over ssh
            command=sprintf('cd %s; python3 detect_devices.py',obj.serverDir);
            % Execute command over ssh and retrieve response
            command_result =  ssh2_command_response(ssh2_command(obj.ssh_struct, command, 0));
            devices = command_result{3:end};
        end

        function info = device_info(obj)
            % Information on SDR devices      
            % Build command to send over ssh
            command=sprintf('cd %s; python3 device_info.py',obj.serverDir);
            % Execute command over ssh and retrieve response
            command_result =  ssh2_command_response(ssh2_command(obj.ssh_struct, command, 0));
            info = command_result{3:end};
        end
        
        function [samples, timeVec] = get_samples(obj, fc, N, gain, sampleRate, repeats, device_id)
            % Retrieve raw time samples in IQ format
            % fc: Centre frequency {24MHz <= fc <= 1800MHz}
            % N: Number of samples
            % gain: Total receiver gain (dB) {0.0<=gain<=45.0}, comprised of
            %       LNA, VGA, MIX stages of 15.0 dB adjustable gain each
            % sampleRate: Sampling rate, {2.5MHz, 10MHz}
            % repeats: Number of times to repeat measurement. Results in
            %           samples = [N x repeats] sized array
            % device_id: Which SDR to use {'0', '1'}
            
            % Build command to send over ssh
            command=sprintf('cd %s; python3 get_samples.py --freq %f --bins %d --gain %f --rate %d --repeats %d --device %d --output %s',...
                            obj.serverDir, fc, N, gain, sampleRate, repeats, device_id, [obj.serverDir,'samples.txt']);
            % Execute command over ssh
            obj.ssh_struct = ssh2_command(obj.ssh_struct, command);
            % Retrieve the data file
            scp_get(obj.ssh_struct,'samples.txt',obj.clientDir,obj.serverDir);
            % Read the samples from file
            samples=readmatrix([obj.clientDir,'samples.txt'],'delimiter',',') ;
            % Construct time vector
            timeVec = (0:1:N-1).*(1/sampleRate);
        end
        
        function [mag, freqVec] = scan_spectrum(obj, freq, bins, gain, rate, repeats, device_id)
            % Scan spectrum with soapy_power (https://github.com/xmikos/soapy_power)
%             usage: soapy_power [-h] [-f Hz|Hz:Hz] [-O FILE | --output-fd NUM] [-F {rtl_power,rtl_power_fftw,soapy_power_bin}] [-q]
%                    [--debug] [--detect] [--info] [--version] [-b BINS | -B Hz] [-n REPEATS | -t SECONDS | -T SECONDS]
%                    [-c | -u RUNS | -e SECONDS] [-d DEVICE] [-C CHANNEL] [-A ANTENNA] [-r Hz] [-w Hz] [-p PPM]
%                    [-g dB | -G STRING | -a] [--lnb-lo Hz] [--device-settings STRING] [--force-rate] [--force-bandwidth]
%                    [--tune-delay SECONDS] [--reset-stream] [-o PERCENT | -k PERCENT] [-s BUFFER_SIZE] [-S MAX_BUFFER_SIZE]
%                    [--even | --pow2] [--max-threads NUM] [--max-queue-size NUM] [--no-pyfftw] [-l] [-R]
%                    [-D {none,constant}] [--fft-window {boxcar,hann,hamming,blackman,bartlett,kaiser,tukey}]
%                    [--fft-window-param FLOAT] [--fft-overlap PERCENT]
%             Main options:
%               -h, --help            show this help message and exit
%               -f Hz|Hz:Hz, --freq Hz|Hz:Hz
%                                     center frequency or frequency range to scan, number can be followed by a k, M or G multiplier
%                                     (default: 1420405752)
%               -O FILE, --output FILE
%                                     output to file (incompatible with --output-fd, default is stdout)
%               --output-fd NUM       output to existing file descriptor (incompatible with -O)
%               -F {rtl_power,rtl_power_fftw,soapy_power_bin}, --format {rtl_power,rtl_power_fftw,soapy_power_bin}
%                                     output format (default: rtl_power)
%               -q, --quiet           limit verbosity
%               --debug               detailed debugging messages
%               --detect              detect connected SoapySDR devices and exit
%               --info                show info about selected SoapySDR device and exit
%               --version             show program's version number and exit
% 
%             FFT bins:
%               -b BINS, --bins BINS  number of FFT bins (incompatible with -B, default: 512)
%               -B Hz, --bin-size Hz  bin size in Hz (incompatible with -b)
% 
%             Averaging:
%               -n REPEATS, --repeats REPEATS
%                                     number of spectra to average (incompatible with -t and -T, default: 1600)
%               -t SECONDS, --time SECONDS
%                                     integration time (incompatible with -T and -n)
%               -T SECONDS, --total-time SECONDS
%                                     total integration time of all hops (incompatible with -t and -n)
% 
%             Measurements:
%               -c, --continue        repeat the measurement endlessly (incompatible with -u and -e)
%               -u RUNS, --runs RUNS  number of measurements (incompatible with -c and -e, default: 1)
%               -e SECONDS, --elapsed SECONDS
%                                     scan session duration (time limit in seconds, incompatible with -c and -u)
% 
%             Device settings:
%               -d DEVICE, --device DEVICE
%                                     SoapySDR device to use
%               -C CHANNEL, --channel CHANNEL
%                                     SoapySDR RX channel (default: 0)
%               -A ANTENNA, --antenna ANTENNA
%                                     SoapySDR selected antenna
%               -r Hz, --rate Hz      sample rate (default: 2000000.0)
%               -w Hz, --bandwidth Hz
%                                     filter bandwidth (default: 0)
%               -p PPM, --ppm PPM     frequency correction in ppm
%               -g dB, --gain dB      total gain (incompatible with -G and -a, default: 37.2)
%               -G STRING, --specific-gains STRING
%                                     specific gains of individual amplification elements (incompatible with -g and -a, example:
%                                     LNA=28,VGA=12,AMP=0
%               -a, --agc             enable Automatic Gain Control (incompatible with -g and -G)
%               --lnb-lo Hz           LNB LO frequency, negative for upconverters (default: 0)
%               --device-settings STRING
%                                     SoapySDR device settings (example: biastee=true)
%               --force-rate          ignore list of sample rates provided by device and allow any value
%               --force-bandwidth     ignore list of filter bandwidths provided by device and allow any value
%               --tune-delay SECONDS  time to delay measurement after changing frequency (to avoid artifacts)
%               --reset-stream        reset streaming after changing frequency (to avoid artifacts)
% 
%             Crop:
%               -o PERCENT, --overlap PERCENT
%                                     percent of overlap when frequency hopping (incompatible with -k)
%               -k PERCENT, --crop PERCENT
%                                     percent of crop when frequency hopping (incompatible with -o)
% 
%             Performance options:
%               -s BUFFER_SIZE, --buffer-size BUFFER_SIZE
%                                     base buffer size (number of samples, 0 = auto, default: 0)
%               -S MAX_BUFFER_SIZE, --max-buffer-size MAX_BUFFER_SIZE
%                                     maximum buffer size (number of samples, -1 = unlimited, 0 = auto, default: 0)
%               --even                use only even numbers of FFT bins
%               --pow2                use only powers of 2 as number of FFT bins
%               --max-threads NUM     maximum number of PSD threads (0 = auto, default: 0)
%               --max-queue-size NUM  maximum size of PSD work queue (-1 = unlimited, 0 = auto, default: 0)
%               --no-pyfftw           don't use pyfftw library even if it is available (use scipy.fftpack or numpy.fft)
% 
%             Other options:
%               -l, --linear          linear power values instead of logarithmic
%               -R, --remove-dc       interpolate central point to cancel DC bias (useful only with boxcar window)
%               -D {none,constant}, --detrend {none,constant}
%                                     remove mean value from data to cancel DC bias (default: none)
%               --fft-window {boxcar,hann,hamming,blackman,bartlett,kaiser,tukey}
%                                     Welch's method window function (default: hann)
%               --fft-window-param FLOAT
%                                     shape parameter of window function (required for kaiser and tukey windows)
%               --fft-overlap PERCENT
%                                     Welch's method overlap between segments (default: 50)
        
            % Create cell array of keyword arguments
            kwargs = {' --freq ',':',' --bins ',' --gain ',' --rate ',' --repeats ',' --device ' ;
                        freq(1), freq(end), bins, gain, rate, repeats, device_id};
            argStr = sprintf('%s%d',kwargs{:});
            % Build command to send over ssh
            command=sprintf('cd %s; soapy_power --format rtl_power_fftw --debug --output scan_output.txt  --crop 20 %s',...
                    obj.serverDir, argStr);
            ssh2_command(obj.ssh_struct, command);
            scp_get(obj.ssh_struct,{'scan_output.txt'},obj.clientDir,obj.serverDir);
            scan_data=readmatrix([obj.clientDir,'scan_output.txt'],'delimiter',' ','CommentStyle','#');
            freqVec=scan_data(:,1);
            mag=scan_data(:,2);
        end
        
        function obj = start_campaign(obj, freq, runs, bins, gain, rate, repeats, device_id)
            % Set control flags
            obj.CTRL.run = 1;
            obj.CTRL.pause=0;
            obj.CTRL.quit=0;
            % Convert to python dictionary structure
            CTRLdict=py.dict(obj.CTRL);
            % Write to file 
            fileID = fopen([obj.campaignDir,'ctrl.txt'],'w');
            fprintf(fileID,'%s\n',CTRLdict);
            fclose(fileID);
            % Send control file to SKAAP
            scp_put(obj.ssh_struct, 'ctrl.txt', [obj.serverDir,'campaign'], obj.campaignDir, 'ctrl.txt')
            % Create cell array of keyword arguments we wish to set
            kwargs = {' --freq ',':',' --bins ',' --gain ',' --rate ',' --repeats ',' --device ' ;
                        freq(1), freq(end), bins, gain, rate, repeats, device_id};
            argStr = sprintf('%s%d',kwargs{:});
            % Handle whether campaign is continous or has a finitite number
            % of runs
            if runs==0
                argStr = [argStr,' --continue'];
            else
                argRun = sprintf(' --runs %d',runs);
                argStr = [argStr, argRun];
            end
            % Build command to send over ssh
            % PID20535: nohup python3 -u ./run_campaign.py --freq 24M:1800M --crop 20 --tune-delay 0.2 --continue --quiet & 
%             obj.ssh_struct.command=sprintf('cd %s/%s; nohup soapy_power --continue --tune-delay 0.05 --format rtl_power_fftw --output %s_output.txt --crop 20 %s &',...
%                     obj.serverDir, name, name, argStr);
            obj.ssh_struct.command=sprintf('cd %s; nohup python3 -u ./run_campaign.py --tune-delay 0.2 --format rtl_power_fftw --crop 20 --quiet %s & > %scampaign/log.out &',...
                    obj.serverDir, argStr, obj.serverDir);
%             ssh2_command(obj.ssh_struct, command);
            obj.ssh_struct.command_session  =  obj.ssh_struct.connection.openSession();
            obj.ssh_struct.command_session.execCommand(obj.ssh_struct.command);
            % Wait 5 seconds and check the status
            pause(5);
            obj = obj.get_status;
            while obj.STATUS.running==0
                pause(5);
                obj = obj.get_status;
            end
        end
        
        function obj = pause_campaign(obj)
            % Set control flags
            obj.CTRL.pause=1;
            % Convert to python dictionary structure
            CTRLdict=py.dict(obj.CTRL);
            % Write to file 
            fileID = fopen([obj.campaignDir,'ctrl.txt'],'w');
            fprintf(fileID,'%s\n',CTRLdict);
            fclose(fileID);
            % Send control file to SKAAP
            obj.ssh_struct.command=sprintf('cd %scampaign; echo "%s" >ctrl.txt',...
                    obj.serverDir, CTRLdict);
            obj.ssh_struct.command_session  =  obj.ssh_struct.connection.openSession();
            obj.ssh_struct.command_session.execCommand(obj.ssh_struct.command);
            % Wait 5 seconds and check the status
            pause(5);
            obj = obj.get_status;
            while obj.STATUS.paused==0
                pause(5);
                obj = obj.get_status;
            end
        end
        
        function obj = resume_campaign(obj)
            % Set control flags
            obj.CTRL.pause=0;
            % Convert to python dictionary structure
            CTRLdict=py.dict(obj.CTRL);
            % Write to file 
            fileID = fopen([obj.campaignDir,'ctrl.txt'],'w');
            fprintf(fileID,'%s\n',CTRLdict);
            fclose(fileID);
            % Send control file to SKAAP
            obj.ssh_struct.command=sprintf('cd %scampaign; echo "%s" >ctrl.txt',...
                    obj.serverDir, CTRLdict);
            obj.ssh_struct.command_session  =  obj.ssh_struct.connection.openSession();
            obj.ssh_struct.command_session.execCommand(obj.ssh_struct.command);
            % Wait 5 seconds and check the status
            pause(5);
            obj = obj.get_status;
            while obj.STATUS.paused==1
                pause(5);
                obj = obj.get_status;
            end
        end
        
        function obj = stop_campaign(obj)
%             obj.ssh_struct.command=sprintf('kill -9 %d;', obj.STATUS.PID);
%             obj.ssh_struct.command_session  =  obj.ssh_struct.connection.openSession();
%             obj.ssh_struct.command_session.execCommand(obj.ssh_struct.command);
            % Set control flags
            obj.CTRL.run=0;
            obj.CTRL.pause=0;
            % Convert to python dictionary structure
            CTRLdict=py.dict(obj.CTRL);
            % Write to file 
            fileID = fopen([obj.campaignDir,'ctrl.txt'],'w');
            fprintf(fileID,'%s\n',CTRLdict);
            fclose(fileID);
            % Send control file to SKAAP
            obj.ssh_struct.command=sprintf('cd %scampaign; echo "%s" >ctrl.txt',...
                    obj.serverDir, CTRLdict);
            obj.ssh_struct.command_session  =  obj.ssh_struct.connection.openSession();
            obj.ssh_struct.command_session.execCommand(obj.ssh_struct.command);
            % Wait 5 seconds and check the status
            pause(5);
            obj = obj.get_status;
            while obj.STATUS.running==1
                pause(5);
                obj = obj.get_status;
            end
        end
        
        function dtimes = read_dtimes(obj)
            T = readtable([obj.campaignDir,'time.txt'],'Format','%s %s','ReadVariableNames',false);
            dtimes.start = datetime(T.Var1);
            dtimes.end = datetime(T.Var2);
        end
        
        function [dtimes,freq,magFull,magMax,magMean,magMin] = campaign_data(obj)              
            dtimes = obj.read_dtimes();
            freq=readmatrix([obj.campaignDir,'freq.txt'],'delimiter',' ','CommentStyle','');
            magMax=readmatrix([obj.campaignDir,'magMax.txt'],'delimiter',' ','CommentStyle','');
            magMean=readmatrix([obj.campaignDir,'magMean.txt'],'delimiter',' ','CommentStyle','');
            magMin=readmatrix([obj.campaignDir,'magMin.txt'],'delimiter',' ','CommentStyle','');         
            magFull = read_magFull([obj.campaignDir,'magFull.txt']);
            % magFull=readmatrix([obj.campaignDir,'magFull.txt'],'delimiter',' ','CommentStyle','');                                          
        end
        
        function update_campaign(obj)
            filenames = {'status.txt','settings.txt','time.txt', 'freq.txt','magFull.txt','magMax.txt','magMean.txt','magMin.txt'};
            if isfolder(obj.campaignDir)
                disp('===============')
                disp('WARNING')
                disp('---------------')
                disp('This will replace local data in, ')
                disp(' ')
                disp(obj.campaignDir)
                disp(' ')
                disp('with current campaign output on server.')
                disp(' ')
                res = input('Do you wish to continue? Y/N: ','s');                    
                val = true;
                while val
                    if ismember(res,{'Y','y','N','n'})
                        val = false;
                        if ismember(res,{'N','n'})
                            error('UPDATE CANCELLED')
                        else
                            scp_get(obj.ssh_struct,filenames,obj.campaignDir,[obj.serverDir,'campaign']);
                        end
                    else
                        disp(' ')
                        res = input('Enter a valid response (Y or N). Do you wish to continue? Y/N: ','s');
                    end
                end
            end                                  
        end                
    end
end
