SerialPort = serial('COM9', 'BaudRate', 115200, 'DataBits', 8, 'StopBits', 1, 'Timeout', 1, 'DataTerminalReady', 'off');

% Send new servo position:
fopen(SerialPort)
fwrite(SerialPort,['A' 130]) 

% Note: range = 130-250

% Terminate connection:c

fclose(SerialPort);