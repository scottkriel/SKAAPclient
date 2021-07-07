% Script to test SKAAPclient() class methods
clear all 
close all

% Create instance and initialize
obj = SKAAPclient();
obj = obj.init();
% Get ambient temperature and humidity inside receiver box
[temp, humidity] = obj.temp_humidity();
fprintf('Temperature: %.1f Celsius \nHumidity: %.1f%% \n',temp,humidity)
% Detect connected SDR devices
devices = obj.detect_devices();
% Get information on SDR devices
sdr_info = obj.device_info();

%Configure measurement parameters
fc = 94e06; % Centre freq
N = 512;  % Number of samples/fft bins
gain = 15.0; % Total receiver gain
sampleRate = 10e06;  % Samples per second
repeats = 1; % Number of spectra to average 
device_id = 0;

% Retrieve raw time samples in IQ-format
[samples, timeVect] = obj.get_samples(fc, N, gain, sampleRate, repeats, device_id);
figure
plot(timeVect./1e-6, real(samples)./1e-3,'DisplayName','In-phase'); hold on,
plot(timeVect./1e-6, imag(samples)./1e-3,'DisplayName', 'Quadrature')
grid on
grid minor
xlabel('Time (\mu{s})')
ylabel('Voltage (mV)')
title('Raw time samples')
% Calculate Fourier spectrum
V = fftshift(fft(samples));
Fs = sampleRate;
df = Fs/N;
freqVect = fc-Fs/2:df:fc+Fs/2-df;
figure
plot(freqVect./1e06,dB10(abs(V)))
xlabel('Frequency (MHz)')
ylabel('Magnitude (dB)')
grid on
grid minor
title('FFT of IQ data')

% The same result can be acheived using the scan_spectrum function
[mag, freqScan] = obj.scan_spectrum(fc, N, gain, sampleRate, repeats, device_id);
figure
plot(freqScan./1e06,mag)
xlabel('Frequency (MHz)')
ylabel('Magnitude (dB)')
grid on
grid minor
title('Result from scan spectrum')

% Close the SSH connection
obj.close_connection();
