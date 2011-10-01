function Spikes = findSpikes(NSx, varargin)
% findSpikes
%
% Searches NSx data structure for spikes by thresholding. The output is
% compatible with NEV.Spikes data structure.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Use OUTPUT = findSpikes(NSx, 'report').
%   
%    NSx:          The data structure holding the NSx structure
%
% NOTE: All following input arguments are optional. Input arguments may be in any order.
%
%   'report':     Will show a summary report if user passes this argument.
%                 DEFAULT: will not show report.
%
%   'threshold':  The next parameter is the
%                 threshold (in micro volts). It can be a row vector.
%                 DEFAULT: -65
%
%   'preThreshold':  The next parameter is the pre-threshold
%                    (number of samples before threshold crossing)
%                 DEFAULT: 10
%
%   'channels':  The next parameter is the channels
%                to look to find spikes.
%                 DEFAULT: all channels
%
%   'duration':  The next parameter is the duration
%                in terms of samples to look over to find spikes.
%                 DEFAULT: all samples
%
%   'spikeLength': The next parameter is Length of each spike
%                 DEFAULT: 48
%
%   'filter':    The next parameter is the 
%                filter to use and can be 'SpikeMedium'
%                 DEFAULT: no filter applied
%
%   OUTPUT:      Contains the NEV.Spikes structure.
%
%   USAGE EXAMPLE: 
%   
%   Spikes = findSpikes(NSx, 'report', 'channels', 1:3, 'duration', 1:10000, 'threshold', -65);
%   
%   In the above example the NSx analog data is searched for spikes among
%   channels 1 to 3 for sample duration between 1 and 10000. Threshold is
%   set to -65uV for all channels.
%
%   Spikes = findSpikes(NSx, 'report', 'channels', 1:3, 'threshold', [-65 -100 -85]);
%   In the above example the NSx analog data is searched for spikes among
%   channels 1 to 3. Thresholds for each channel is specified in uV.
%
%   Original Author: Ehsan Azar
%
%   Contributors: 
%   Kian Torab, Blackrock Microsystems, ktorab@blackrockmicro.com
%
%   Version 1.0.0.0
%

Spikes = struct('TimeStamp', [],'Electrode', [], 'Unit', [],'Waveform', [], 'findSpikesVer', []);
Spikes.findSpikesVer = '1.0.0.0';

%% Validating the input arguments. Exit with error message if error occurs.
spikelen = 48;
threshold = -65;
preThreshold = 10;
filtType = '';
next = '';
for i=1:length(varargin)
    inputArgument = varargin{i};
    if (strcmpi(next, 'threshold'))
        next = '';
        threshold = inputArgument;
    elseif (strcmpi(next, 'preThreshold'))
        next = '';
        preThreshold = inputArgument;
    elseif (strcmpi(next, 'channels'))
        next = '';
        channels = inputArgument;
    elseif (strcmpi(next, 'duration'))
        next = '';
        duration = inputArgument;
    elseif (strcmpi(next, 'spikeLength'))
        next = '';
        spikelen = inputArgument;
    elseif (strcmpi(next, 'filter'))
        next = '';
        if (strfind(' SpikeMedium ', [' ' inputArgument ' ']) ~= 0)
            filtType = inputArgument;
        end
    elseif strcmpi(inputArgument, 'report')
        Report = inputArgument;
    elseif strcmpi(inputArgument, 'threshold')
        next = 'threshold';
    elseif strcmpi(inputArgument, 'preThreshold')
        next = 'preThreshold';        
    elseif strcmpi(inputArgument, 'channels')
        next = 'channels';        
    elseif strcmpi(inputArgument, 'duration')
        next = 'duration';        
    elseif strcmpi(inputArgument, 'spikeLength')
        next = 'spike length';        
    elseif strcmpi(inputArgument, 'filter')
        next = 'filter'; 
    end
end
clear next;

%% Give all input arguments a default value. All input argumens are
%  optional.
if ~exist('Report', 'var');      Report = 'noreport'; end
if ~exist('channels', 'var');    channels = (1:size(NSx.Data, 1))'; end
if ~exist('duration', 'var');    duration = (1:size(NSx.Data, 2))'; end

%% Apply filter
Data = NSx.Data(channels, duration).';

switch (filtType)
    case 'SpikeMedium'
        [b, a] = butter(4, 250/15000, 'high'); % Spike medium
        Data = filter(b, a, Data);
end

%% Threshold
if isfield(NSx, 'ElectrodesInfo');
    if (isscalar(threshold) && all([NSx.ElectrodesInfo(channels).MaxAnalogValue] == NSx.ElectrodesInfo(1).MaxAnalogValue) && ...
            all([NSx.ElectrodesInfo(channels).MaxDigiValue] == NSx.ElectrodesInfo(1).MaxDigiValue))
        threshold = (threshold * double(NSx.ElectrodesInfo(1).MaxDigiValue) / ...
            double(NSx.ElectrodesInfo(1).MaxAnalogValue)); % scalar threshold
    else
        threshold = (threshold .* double([NSx.ElectrodesInfo(channels).MaxDigiValue]) ./ ...
            double([NSx.ElectrodesInfo(channels).MaxAnalogValue])); % vector threshold
    end
    threshold = cast(threshold, class(Data));
end

[row, col] = find((diff(bsxfun(@minus, Data, threshold) > 0) < 0).');
clear threshold;
Spikes.TimeStamp = col' - preThreshold;
clear col;
Spikes.Electrode = row';
clear row;

Spikes.Electrode(Spikes.TimeStamp < 1) = [];
Spikes.TimeStamp(Spikes.TimeStamp < 1) = [];
Spikes.Electrode(Spikes.TimeStamp + spikelen > size(NSx.Data, 2)) = [];
Spikes.TimeStamp(Spikes.TimeStamp + spikelen > size(NSx.Data, 2)) = [];

%% Lockout violation removal
% this makes sure all spikes are at least one spike length apart
ii = 1;
while (ii < length(Spikes.TimeStamp))
    idx = find((Spikes.Electrode((ii+1):end) == Spikes.Electrode(ii)) & ...
        (Spikes.TimeStamp((ii+1):end) - Spikes.TimeStamp(ii) >= spikelen), 1);
    if (isempty(idx))
        idx = find(Spikes.Electrode((ii+1):end) == Spikes.Electrode(ii));
    else
        idx = find(Spikes.Electrode((ii+1):(ii+idx-1)) == Spikes.Electrode(ii));
    end
    if (~isempty(idx))
        Spikes.Electrode(ii + idx) = [];
        Spikes.TimeStamp(ii + idx) = [];
    end
    ii = ii + 1;
end
clear idx;

%% Spike extraction
Spikes.Waveform = zeros(spikelen, length(Spikes.TimeStamp));
for ii = 1:length(Spikes.TimeStamp)
    ts = Spikes.TimeStamp(ii):(Spikes.TimeStamp(ii) + spikelen - 1);
    Spikes.Waveform(:, ii) = Data(ts, Spikes.Electrode(ii));
end
% convert index to actual channel number
Spikes.Electrode = channels(Spikes.Electrode);


