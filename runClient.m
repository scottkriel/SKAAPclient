% % Script to test SKAAPclient() class methods
% clear all 
% close all
% % Create instance and initialize
% obj = SKAAPclient();
% obj = obj.init();
% obj.update_campaign();
[dtimes,freq,magFull,magMax,magMean,magMin] = campaign_data(obj);
figure 
plot(freq./1e06,magFull,'LineStyle','none','Marker','.','MarkerSize',1e-12)
xlabel('Frequency (MHz)')
ylabel('Magnitude (dB)')
grid on 
grid minor
% 
figure
plot(freq./1e06,magMax, 'color','r','DisplayName','Max'); hold on,
plot(freq./1e06,magMean, 'color','g','DisplayName','Mean'); hold on,
plot(freq./1e06,magMin, 'color','b','DisplayName','Min'); hold on,
grid on
grid minor
xlabel('Frequency (MHz)')
ylabel('Magnitude (dB)')
grid on 
grid minor

freqInterp = linspace(min(freq),max(freq),500);
dtimesInterp = linspace(dtimes.start(1),dtimes.start(end),100);
[Xq,Yq] = meshgrid(freqInterp,posixtime(dtimesInterp));
magInterp = interp2(freq,posixtime(dtimes.start),magFull,Xq,Yq,'spline');

[X,Y] = meshgrid(freq,posixtime(dtimes.start));
figure
scatter(X(:)./1e06,Y(:),[],magFull(:))
colormap('jet')
colorbar
grid on
grid minor
xlabel('Frequency (MHz)')
ylabel('Time (datetime)')

figure
surf(freq./1e06,dtimes.start,magFull,'FaceColor','interp','EdgeColor','none')
colormap('jet')
colorbar
grid on
grid minor
xlabel('Frequency (MHz)')
ylabel('Time (datetime)')

figure
surf(freqInterp./1e06,dtimesInterp,magInterp,'FaceColor','interp')
colormap('jet')
colorbar
grid on
grid minor
xlabel('Frequency (MHz)')
ylabel('Time (datetime)')

ctrl = struct('run',1,'pause',0,'quit',0);
ctrlDict=py.dict(ctrl);
fileID = fopen('ctrl.txt','w');
fprintf(fileID,'%s\n',ctrlDict);
fclose(fileID);





