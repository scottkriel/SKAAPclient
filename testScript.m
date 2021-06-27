clear all;
close all;

currDir=pwd;
HOSTNAME='146.232.220.129';
USERNAME='pi';
PASSWORD='skaap123';
serverDir ='$HOME/SKAAP/SKAAPserver/';
clientDir = pwd;

ssh_conn = ssh2_config(HOSTNAME,USERNAME,PASSWORD);
command=sprintf('cd %s; python temp_humidity.py',serverDir);
ssh_conn = ssh2_command(ssh_conn, command);
command=sprintf('cd %s; python detect_devices.py',serverDir);
ssh_conn = ssh2_command(ssh_conn, command);
command=sprintf('cd %s; python device_info.py',serverDir);
ssh_conn = ssh2_command(ssh_conn, command,1);
command=sprintf('cd %s; python get_samples.py -O output.txt',serverDir);
ssh_conn = ssh2_command(ssh_conn, command);
scp_get(ssh_conn,{'output.txt'},clientDir,serverDir);
samples=readmatrix('output.txt','TrimNonNumeric',1) ;
% fc = 94e06; % Centre frequency
% N=65536; % Number of samples/bins. Max N=65536
% gain=15.0; % Total gain
% sampleRate=10e06; % Sample rate: either 2.5MHz or 10MHz
% device_id_str='0'; % SDR device ID: '0' or '1'
% command=sprintf('cd $HOME/SKAAP/; python run_measurement.py %d',fc);
% ssh_conn = ssh2_command(ssh_conn, command);
% ssh_conn = scp_get(ssh_conn,{'time0.npy','freq.npy','data0.npy'},clientDir,'$HOME/SKAAP/');
% time_spec=readNPY(strcat(clientDir,'\time0.npy')); 
% freq_spec=readNPY(strcat(clientDir,'\freq.npy'));
% mag_spec=readNPY(strcat(clientDir,'\data0.npy'));
% dtime_spec = datetime(time_spec, 'ConvertFrom', 'posixtime','timezone','Africa/Johannesburg');
% 
% figure
% plot(freq_spec./1e06,mag_spec)
% grid on
% grid minor
% xlabel('Frequency (MHz)')
% ylabel('Magnitude (dB)')
% grid on 
% grid minor
% title(string(dtime_spec))
% 
% 
% command=sprintf('cd %s; soapy_power -r %d -f %d -b %d -g %.2f -k 0 -n 1 -F rtl_power_fftw -O scan_output.txt --debug',serverDir,sampleRate,fc,N,gain);
% ssh_conn = ssh2_command(ssh_conn, command);
% scp_get(ssh_conn,{'scan_output.txt'},clientDir,serverDir);
% scan_data=readmatrix(strcat(clientDir,'\scan_output.txt'));
% freq_scan=scan_data(:,1);
% mag_scan=scan_data(:,2);
% 
% figure
% plot(freq_scan./1e06,mag_scan)
% grid on
% grid minor
% xlabel('Frequency (MHz)')
% ylabel('Magnitude (dB)')
% grid on 
% grid minor
% 
% ssh_conn = ssh2_close(ssh_conn);


% ssh2_conn = scp_simple_get(HOSTNAME,USERNAME,PASSWORD,'data0.npy','$HOME/SKAAP/');
% ssh2_conn.command_result
% ssh2_conn = ssh2_command(ssh2_conn, 'cd Desktop');
% ssh2_conn.command_result
% ssh2_conn = ssh2_command(ssh2_conn, 'ls');
% ssh2_conn.command_result
% 
% command_output = ssh2_simple_command(HOSTNAME,USERNAME,PASSWORD,'python $HOME/SKAAP/run_measurement.py')