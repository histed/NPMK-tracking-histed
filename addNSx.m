function NSx = addNSx(NSx1, NSx2, varargin)
% addNSx
%
% Adds NSx2 to NSx1 correcting the timestamps or channel count. Make sure to use 
%  the latest openNSx to read NSx1 and NSx2 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Use NSx = addNSx(NSx1, NSx2, 'report').
%   
%    NSx1:        The main data structure or NSx file name
%    NSx2:        The second data structure or NSx file name
%
% NOTE: All following input arguments are optional. Input arguments may be in any order.
%
%   'report':     Will show a summary report if user passes this argument.
%                 DEFAULT: will not show report.
%
%   'addchan':    Will add the channels in NSx2 to channels in NSx1,
%                  incresing the total number of channels.
%                 DEFAULT: will not add channels
%
%   'norestamp':  Do not use datetime to re-stamp the events in NSx2.
%                 DEFAULT: will use datetime to re-stamp the events
%   
%   'offset':     The next parameter is the manual extra timestap offset 
%                 (in seconds) to add to NSx1 timestamp
%                 DEFAULT: 0
%
%   OUTPUT:      Contains NSx structure of combined NSx1 and NSx2
%
%   USAGE EXAMPLE: 
%   
%   NSx = addNSx(NSx, NSx2, 'report', 'offset', 1);
%   
%   In the above example data in NSx2 is added to NSx, a manual offset 
%   of 1 seconds is added in addition of restamping NSx2 by datetime
%   difference.
%
%   NSx = addNSx('c:\target.ns5', 'c:\source.ns5', 'report', 'offset', 1, 'norestamp');
%
%   In the above example the NSx file in 'source.ns5' is added to the
%   end of 'target.ns5'. 
%   Only a manual offset of 1 seconds is added to
%   the events in 'source.ns5' and datetime difference is not considered.
%
%   Original Author: Ehsan Azar
%
%   Contributors: 
%   Kian Torab, Blackrock Microsystems, kianabc@kianabc.com
%
%   Version 1.0.0.0
%
NSx.addNSxver = '1.0.0.0';
%% Validating the input arguments. Exit with error message if error occurs.
restamp = 'restamp';
addchan = 'noaddchan';
Report = 'noreport';
offset = 0;
next = '';
for i=1:length(varargin)
    inputArgument = varargin{i};
    if (strcmpi(next, 'offset'))
        next = '';
        offset = inputArgument * NSx1.MetaTags.SamplingFreq;
    elseif strcmpi(inputArgument, 'noreport')
        Report = inputArgument;
    elseif strcmpi(inputArgument, 'report')
        Report = inputArgument;
    elseif strcmpi(inputArgument, 'addchan')
        addchan = inputArgument;
        disp('not implemented yet');
    elseif strcmpi(inputArgument, 'norestamp')
        restamp = inputArgument;
    elseif strcmpi(inputArgument, 'offset')
        next = 'offset';
    end
end
clear next;

if strcmpi(Report, 'report')
    disp(['addNSx version ' NSx.addNSxver])
end

%% inherit properties
FileAddOption = false;
if ischar(NSx1)
    NSx1 = openNSx(NSx1, Report, 'noread');
    FileAddOption = true;
end
if ischar(NSx2)
    NSx2 = openNSx(NSx2, Report, 'noread');
    FileAddOption = true;
end

%% restamp and add data
if strcmpi(restamp, 'restamp')
    if isempty(NSx2.MetaTags.DateTimeRaw)
        if strcmpi(Report, 'report')
            disp('Restamp ignored, the header must include datetime to restamp.');
        end
    else
        offset = offset + floor(double(NSx2.MetaTags.DateTimeRaw(5:8) -  NSx1.MetaTags.DateTimeRaw(5:8)) * [3600 60 1 0.001].' * double(NSx1.MetaTags.SamplingFreq));
    end
end

%% Add files in raw form
if FileAddOption
    NSx = NSx1;
    NSx.MetaTags.NumofPackets = NSx.MetaTags.NumofPackets + NSx2.MetaTags.NumofPackets;
    if (offset < 0)
        if strcmpi(Report, 'report')
            disp('File merge cannot handle negative offset\n second file timestamps must preceed the first file');
        end
        offset = 0;
    end
    recLength = memory;
    % how many packets I can read in memory at once
    recLength = floor((recLength.MaxPossibleArrayBytes / 4) / (NSx.MetaTags.ChannelCount * 2 ));
    fname = fullfile(NSx1.MetaTags.FilePath, NSx1.MetaTags.Filename);
    FID1 = fopen(fname, 'r+', 'ieee-le');
    if (FID1 <= 0)
        disp(['cannot open ' fname ' for appending']);
        return;
    end
    fname = fullfile(NSx2.MetaTags.FilePath, NSx2.MetaTags.Filename);
    FID2 = fopen(fname, 'r', 'ieee-le');
    if (FID2 <= 0)
        disp(['cannot open ' fname ' for reading']);
        return;
    end
    % record number of packets
    if strcmpi(NSx.MetaTags.FileTypeID, 'NEURALCD')
        fseek(FID1, NSx1.MetaTags.HeaderOffset - 4, 'bof');
        fwrite(FID1, NSx.MetaTags.NumofPackets, 'uint32');
    end
    PacketBytes = (NSx.MetaTags.ChannelCount * 2);
    fseek(FID1, NSx1.MetaTags.HeaderOffset + NSx1.MetaTags.NumofPackets * PacketBytes, 'bof');
    % read from NEV2 and append to NEV1 end
    fseek(FID2, NSx2.MetaTags.HeaderOffset, 'bof');
    count = NSx2.MetaTags.NumofPackets; % total packets to be appended
    while count > 0
        if (count < recLength)
            recLength = count;
        end
        rawData  = fread(FID2, [PacketBytes recLength], '*int8');
        fwrite(FID1, rawData(:), 'int8');
        count = count - recLength;
    end
    fclose(FID2);
    fclose(FID1);
    return;
end

%% Add data structures
% not implemented yet
