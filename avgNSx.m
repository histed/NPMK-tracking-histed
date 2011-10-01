function avgNSx = avgNSx(NSx, varargin)
% findSpikes
%
% Averages NSx data structure around given times. 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Use OUTPUT = avgNSx(NSx, 'report').
%   
%    NSx:          The data structure holding the NSx structure
%
%   'timeStamp':  The next parameter is the time stamp of events to average around
%
% NOTE: All following input arguments are optional. Input arguments may be in any order.
%
%   'report':     Will show a summary report if user passes this argument.
%                 DEFAULT: will not show report.
%
%   'window':   The next parameter is the
%                 window around event (in samples)
%                 DEFAULT: [-10 48]
%
%   'channels':  The next parameter is the channels
%                to look for averaging
%                 DEFAULT: first channel
%
%   OUTPUT:      Contains the average
%
%   USAGE EXAMPLE: 
%   
%   ts{1} = NEV.Data.Spikes.TimeStamp(NEV.Data.Spikes.Electrode == 1 & ...
%                                   NEV.Data.Spikes.Unit == 1)
%   ts{2} = NEV.Data.SerialDigitalIO.TimeStamp;
%                                   
%   avg = avgNSx(NSx, 'report', 'channels', 1, 'window', ...
%            [-10 38], 'timeStamp', ts);
%   
%   In the above example the NSx analog data is averaged for
%   channel 1 around spikes with unit classification of 1 with a window
%   with -10 samples before the event and 38 samples after the event.
%
%   ts{1,1} = NEV.Data.Spikes.TimeStamp(NEV.Data.Spikes.Electrode == 1 & ...
%                                   NEV.Data.Spikes.Unit == 1)
%   ts{1,2} = NEV.Data.SerialDigitalIO.TimeStamp;
%   ts{2,1} = NEV.Data.Spikes.TimeStamp(NEV.Data.Spikes.Electrode == 17 & ...
%                                   NEV.Data.Spikes.Unit == 0)
%                                   
%   avg = avgNSx(NSx, 'report', 'channels', [1 17], 'timeStamp', ts);
%
%   In the above example channel 1 is set to average for unit1
%   classification spike firing, and also digital events. 
%   Channel 17 is set to average for unclassified spike firing.
%
%   Original Author: Ehsan Azar
%
%   Contributors: 
%   Kian Torab, Blackrock Microsystems, kianabc@kianabc.com
%
%   Version 1.0.0.0
%

%% Validating the input arguments. Exit with error message if error occurs.
channels = 1;
avgWindow = [-10 48];
next = '';
for i=1:length(varargin)
    inputArgument = varargin{i};
    if (strcmpi(next, 'window'))
        next = '';
        avgWindow = inputArgument;
    elseif (strcmpi(next, 'timeStamp'))
        next = '';
        ts = inputArgument;
    elseif (strcmpi(next, 'channels'))
        next = '';
        channels = inputArgument;
    elseif strcmpi(inputArgument, 'report')
        Report = inputArgument;
    elseif strcmpi(inputArgument, 'window')
        next = 'window';
    elseif strcmpi(inputArgument, 'timeStamp')
        next = 'timeStamp';        
    elseif strcmpi(inputArgument, 'channels')
        next = 'channels';        
    end
end
clear next;

avgNSx = cell(size(ts, 1), size(ts, 2));

if (size(ts, 1) ~= length(channels))
    disp('Timestamps for some channels not provided');
    return;
end
if size(NSx.Data, 1) < max(channels)
    disp('NSx data does not have all necessary channels');
    return;
end

for chan = 1:size(ts, 1)
    for idx = 1:size(ts, 2)
        if ~isempty(ts{chan, idx})
            timeIdx = uint32(floor(double(ts{chan, idx}) / NSx.MetaTags.SamplingFreq));
            timeIdx(timeIdx +  avgWindow(1) < 1) = [];
            timeIdx(timeIdx +  avgWindow(2) > size(NSx.Data, 2)) = [];
            avg = zeros(1, avgWindow(2) - avgWindow(1) + 1);
            for ii = 1:length(timeIdx)
                avg = avg + double(NSx.Data(channels(chan), (timeIdx(ii) + avgWindow(1)):(timeIdx(ii) + avgWindow(2))));
            end
            avg = avg / length(timeIdx);
            avgNSx{chan, idx} = avg;
        end
    end
end


