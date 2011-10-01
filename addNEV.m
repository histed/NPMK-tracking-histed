function NEV = addNEV(NEV1, NEV2, varargin)
% addNEV
%
% Adds NEV2 to NEV1 correcting the timestamps or channel count. Make sure to use 
%  the latest openNEV to read NEV1 and NEV2 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Use NEV = addNEV(NEV1, NEV2, 'report').
%   
%    NEV1:        The main data structure or NEV file name
%    NEV2:        The second data structure or NEV file name
%
% NOTE: All following input arguments are optional. Input arguments may be in any order.
%
%   'report':     Will show a summary report if user passes this argument.
%                 DEFAULT: will not show report.
%
%   'addchan':    Will add the channels in NEV2 to channels in NEV1,
%                  incresing the total number of channels.
%                 DEFAULT: will not add channels
%
%   'norestamp':  Do not use datetime to re-stamp the events in NEV2.
%                 DEFAULT: will use datetime to re-stamp the events
%   
%   'offset':     The next parameter is the manual extra timestap offset 
%                 (in seconds) to add to NEV1 timestamp
%                 DEFAULT: 0
%
%   OUTPUT:      Contains NEV structure of combined NEV1 and NEV2
%
%   USAGE EXAMPLE: 
%   
%   NEV = addNEV(NEV, NEV2, 'report', 'offset', 1);
%   
%    In the above example data in NEV2 is added to NEV, a manual offset 
%    of 1 seconds is added in addition of restamping NEV2 by datetime
%    difference.
%
%   NEV = addNEV('c:\data\target.nev', 'c:\data\source.nev', 'report', 'offset', 1, 'norestamp');
%
%    In the above example the NEV file in 'source.nev' is added to the
%    end of 'target.nev'. 
%    Only a manual offset of 1 seconds is added to the events in 'source.nev' 
%    datetime difference is not considered, and may be forced to the last timestap of 'target.nev' event.
%
%   NEV = addNEV('c:\data\target.nev', 'c:\data\source.nev', 'report');
%
%    In the above example the NEV file in 'source.nev' is added to the
%    end of 'target.nev'.
%    The datetime difference of the source file is added to the timestap of merged data.
%    If datetime difference is negative or merged data still have timestamp less than target, then 
%    merged timestamp is forced to the last timestap of 'target.nev' event.
%
%   Original Author: Ehsan Azar
%
%   Contributors: 
%   Kian Torab, Blackrock Microsystems, kianabc@kianabc.com
%
%   Version 1.1.0.0
%
NEV.addNEVver = '1.1.0.0';
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
        offset = inputArgument * NEV1.MetaTags.SampleRes;
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
    disp(['addNEV version ' NEV.addNEVver])
end

%% inherit properties
FileAddOption = false;
if ischar(NEV1)
    NEV1 = openNEV(NEV1, Report, 'noread', 'nomat', 'nosave', 'noparse', 'HeaderOnly');
    FileAddOption = true;
end
if ischar(NEV2)
    NEV2 = openNEV(NEV2, Report, 'noread', 'nomat', 'nosave', 'noparse', 'HeaderOnly');
    FileAddOption = true;
end
NEV.MetaTags = NEV1.MetaTags;
NEV.ElectrodesInfo= NEV1.ElectrodesInfo;
if isfield(NEV1, 'ArrayInfo')
    NEV.ArrayInfo = NEV1.ArrayInfo;
end
if isfield(NEV1, 'NSAS')
    NEV.NSAS = NEV1.NSAS;
end
if isfield(NEV1, 'VideoSyncInfo')
    NEV.VideoSyncInfo = NEV1.VideoSyncInfo;
end
if isfield(NEV1, 'ObjTrackInfo')
    NEV.ObjTrackInfo = NEV1.ObjTrackInfo;
end
NEV.Data.Spikes.WaveformUnit = NEV1.Data.Spikes.WaveformUnit;

%% restamp and add data
if strcmpi(restamp, 'restamp')
    offset = offset + floor(double(NEV2.MetaTags.DateTimeRaw(5:8) - ...
             NEV1.MetaTags.DateTimeRaw(5:8)) * [3600 60 1 0.001].' * double(NEV1.MetaTags.SampleRes));
end

%% Add files in raw form
if FileAddOption
    NEV = NEV1;
    NEV.MetaTags.PacketCount = NEV.MetaTags.PacketCount + NEV2.MetaTags.PacketCount;
    if (offset < 0)
        if strcmpi(Report, 'report')
            disp('File merge cannot handle negative offset\n second file timestamps must preceed the first file');
        end
        offset = 0;
    end
    recLength = memory;
    % how many packets I can read in memory at once
    recLength = floor((recLength.MaxPossibleArrayBytes / 4) / NEV.MetaTags.PacketBytes);
    fname = [fullfile(NEV1.MetaTags.FilePath, NEV1.MetaTags.Filename) '.nev'];
    FID1 = fopen(fname, 'a', 'ieee-le');
    if (FID1 <= 0)
        disp(['cannot open ' fname ' for appending']);
        return;
    end
    fname = [fullfile(NEV2.MetaTags.FilePath, NEV2.MetaTags.Filename) '.nev'];
    FID2 = fopen(fname, 'r', 'ieee-le');
    if (FID2 <= 0)
        disp(['cannot open ' fname ' for reading']);
        return;
    end
    % read from NEV2 and append to NEV1 end
    fseek(FID2, NEV2.MetaTags.HeaderOffset, 'bof');
    count = NEV2.MetaTags.PacketCount; % total packets to be appended
    while count > 0
        if (count < recLength)
            recLength = count;
        end
        rawData  = fread(FID2, [NEV2.MetaTags.PacketBytes/4 recLength], '*uint32');
        if (count == NEV2.MetaTags.PacketCount)
            if (NEV1.MetaTags.DataDuration > rawData(1, 1) + offset)
                offset = NEV1.MetaTags.DataDuration;
                if strcmpi(Report, 'report')
                    disp(['offset forced to the end of the target file' char(10) ...
                        ' using ''restamp'' on consecutive recordings might prevent this'])
                end
            end
            NEV.MetaTags.DataDuration = rawData(1, end) + offset;
        end
        rawData(1, :) = rawData(1, :) + offset;
        fwrite(FID1, rawData(:), 'uint32');
        count = count - recLength;
    end
    fclose(FID2);
    fclose(FID1);
    return;
end

%% Add data structures
% Spikes
if (offset > 0)
    NEV.Data.Spikes.TimeStamp = [NEV1.Data.Spikes.TimeStamp NEV2.Data.Spikes.TimeStamp+offset];
else
    NEV.Data.Spikes.TimeStamp = [NEV1.Data.Spikes.TimeStamp-offset NEV2.Data.Spikes.TimeStamp];
end
[NEV.Data.Spikes.TimeStamp, idx] = sort(NEV.Data.Spikes.TimeStamp);
NEV.Data.Spikes.Electrode = [NEV1.Data.Spikes.Electrode NEV2.Data.Spikes.Electrode];
NEV.Data.Spikes.Electrode = NEV.Data.Spikes.Electrode(idx);
NEV.Data.Spikes.Unit = [NEV1.Data.Spikes.Unit NEV2.Data.Spikes.Unit];
NEV.Data.Spikes.Unit = NEV.Data.Spikes.Unit(idx);
NEV.Data.Spikes.Waveform = [NEV1.Data.Spikes.Waveform NEV2.Data.Spikes.Waveform];
NEV.Data.Spikes.Waveform = NEV.Data.Spikes.Waveform(:, idx);
clear idx;

% serial and digital
if (offset > 0)
    NEV.Data.SerialDigitalIO.TimeStamp = [NEV1.Data.SerialDigitalIO.TimeStamp NEV2.Data.SerialDigitalIO.TimeStamp+offset];
else
    NEV.Data.SerialDigitalIO.TimeStamp = [NEV1.Data.SerialDigitalIO.TimeStamp-offset NEV2.Data.SerialDigitalIO.TimeStamp];
end
[NEV.Data.SerialDigitalIO.TimeStamp, idx] = sort(NEV.Data.SerialDigitalIO.TimeStamp);
NEV.Data.SerialDigitalIO.InsertionReason = [NEV1.Data.SerialDigitalIO.InsertionReason NEV2.Data.SerialDigitalIO.InsertionReason];
NEV.Data.SerialDigitalIO.InsertionReason = NEV.Data.SerialDigitalIO.InsertionReason(idx);
NEV.Data.SerialDigitalIO.UnparsedData = [NEV1.Data.SerialDigitalIO.UnparsedData NEV2.Data.SerialDigitalIO.UnparsedData];
NEV.Data.SerialDigitalIO.UnparsedData = NEV.Data.SerialDigitalIO.UnparsedData(idx);
clear idx;

% video synch
if (offset > 0)
    NEV.Data.VideoSync.TimeStamp = [NEV1.Data.VideoSync.TimeStamp NEV2.Data.VideoSync.TimeStamp+offset];
else
    NEV.Data.VideoSync.TimeStamp = [NEV1.Data.VideoSync.TimeStamp-offset NEV2.Data.VideoSync.TimeStamp];
end
[NEV.Data.VideoSync.TimeStamp, idx] = sort(NEV.Data.VideoSync.TimeStamp);
NEV.Data.VideoSync.FileNumber = [NEV1.Data.VideoSync.FileNumber NEV2.Data.VideoSync.FileNumber];
NEV.Data.VideoSync.FileNumber = NEV.Data.VideoSync.FileNumber(idx);
NEV.Data.VideoSync.FrameNumber = [NEV1.Data.VideoSync.FrameNumber NEV2.Data.VideoSync.FrameNumber];
NEV.Data.VideoSync.FrameNumber = NEV.Data.VideoSync.FrameNumber(idx);
NEV.Data.VideoSync.SourceID = [NEV1.Data.VideoSync.SourceID NEV2.Data.VideoSync.SourceID];
NEV.Data.VideoSync.SourceID = NEV.Data.VideoSync.SourceID(idx);
NEV.Data.VideoSync.ElapsedTime = [NEV1.Data.VideoSync.ElapsedTime NEV2.Data.VideoSync.ElapsedTime];
NEV.Data.VideoSync.ElapsedTime = NEV.Data.VideoSync.ElapsedTime(idx);
clear idx;

% comment
if (offset > 0)
    NEV.Data.Comments.TimeStamp = [NEV1.Data.Comments.TimeStamp NEV2.Data.Comments.TimeStamp+offset];
else
    NEV.Data.Comments.TimeStamp = [NEV1.Data.Comments.TimeStamp-offset NEV2.Data.Comments.TimeStamp];
end
[NEV.Data.Comments.TimeStamp, idx] = sort(NEV.Data.Comments.TimeStamp);
NEV.Data.Comments.CharSet = [NEV1.Data.Comments.CharSet NEV2.Data.Comments.CharSet];
NEV.Data.Comments.CharSet = NEV.Data.Comments.CharSet(idx);
NEV.Data.Comments.Color = [NEV1.Data.Comments.Color NEV2.Data.Comments.Color];
NEV.Data.Comments.Color = NEV.Data.Comments.Color(idx);
NEV.Data.Comments.Comments = [NEV1.Data.Comments.Comments; NEV2.Data.Comments.Comments];
NEV.Data.Comments.Comments = NEV.Data.Comments.Comments(idx, :);
clear idx;

% TODO:tracking
% TODO:trigger
% TODO:reconfig
