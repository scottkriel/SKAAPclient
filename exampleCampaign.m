% Script to test campaign functions
clear all 
close all
% Create instance and initialize
obj = SKAAPclient();
obj = obj.init();
% Setup campaign properties
freq_range = [80e06, 100e06];
runs = 10;
bins=512;
gain=15.0;
rate=10e06;
repeats=1; % Number of times to average data
device_id=0;
% Start campaign
obj = obj.start_campaign(freq_range, runs, bins, gain, rate, repeats, device_id);
obj = obj.get_status;
while obj.STATUS.running
    pause(2);
    obj = obj.get_status;
end
% Pull the latest campaign data off the server
obj.update_campaign();
[dtimes,freq,magFull,magMax,magMean,magMin] = campaign_data(obj);
obj.close_connection;
% Plot each run on top of eachother
figure 
plot(freq./1e06,magFull,'LineStyle','none','Marker','.','MarkerSize',1e-12)
xlabel('Frequency (MHz)')
ylabel('Magnitude (dB)')
grid on 
grid minor
% Plot the max, mean and min lines
figure
plot(freq./1e06,magMax, 'color','r','DisplayName','Max'); hold on,
plot(freq./1e06,magMean, 'color','g','DisplayName','Mean'); hold on,
plot(freq./1e06,magMin, 'color','b','DisplayName','Min'); hold on,
grid on
grid minor
xlabel('Frequency (MHz)')
ylabel('Magnitude (dB)')
legend('Location','best')
% Plot spectogram
figure
surf(freq./1e06,dtimes.start,magFull,'FaceColor','interp','EdgeColor','none')
colormap('jet')
colorbar
grid on
grid minor
xlabel('Frequency (MHz)')
ylabel('Time (datetime)')

% Create instance and initialize
obj = SKAAPclient();
obj = obj.init();
% Setup campaign properties
freq_range = [24e06, 1750e06]; % Freq limit of SDR is between 24MHz and 1800MHz
runs = 0;   % Zero here means it will run endlessly
bins=512;
gain=15.0;
rate=10e06;
repeats=1; % Number of times to average data
device_id=0;
% Start campaign
obj = obj.start_campaign(freq_range, runs, bins, gain, rate, repeats, device_id);
obj = obj.get_status;
while obj.STATUS.Nsweep==0
    pause(2);
    obj = obj.get_status;
end
obj = obj.pause_campaign;
% Pull the latest campaign data off the server
obj.update_campaign();
[dtimes,freq,magFull,magMax,magMean,magMin] = campaign_data(obj);
% Plot each run on top of eachother
figure 
plot(freq./1e06,magFull,'LineStyle','none','Marker','.','MarkerSize',1e-12)
xlabel('Frequency (MHz)')
ylabel('Magnitude (dB)')
grid on 
grid minor
% Plot the max, mean and min lines
figure
plot(freq./1e06,magMax, 'color','r','DisplayName','Max'); hold on,
plot(freq./1e06,magMean, 'color','g','DisplayName','Mean'); hold on,
plot(freq./1e06,magMin, 'color','b','DisplayName','Min'); hold on,
grid on
grid minor
xlabel('Frequency (MHz)')
ylabel('Magnitude (dB)')
legend('Location','best')
% Plot spectogram
figure
surf(freq./1e06,dtimes.start,magFull,'FaceColor','interp','EdgeColor','none')
colormap('jet')
colorbar
grid on
grid minor
xlabel('Frequency (MHz)')
ylabel('Time (datetime)') 
% Decide whether to continue or not
res = input('Do you wish to continue with the campaign? Y/N: ','s');                    
val = true;
while val
    if ismember(res,{'Y','y','N','n'})
        val = false;
        if ismember(res,{'N','n'})
            obj = obj.stop_campaign;
            obj.close_connection;
        else
            obj = obj.resume_campaign;
        end
    else
        disp(' ')
        res = input('Enter a valid response (Y or N). Do you wish to continue? Y/N: ','s');
    end
end

