function varargout = openNSx(varargin)

% openNSx
% 
% Opens and reads an NSx file then returns all file information in a NSx
% structure. Works with File Spec 2.1 and 2.2.
% Use OUTPUT = openNSx(fname, 'read', 'report', 'electrodes', 'channels', 'duration', 'mode', 'precision', 'skipfactor').
% 
% All input arguments are optional. Input arguments can be in any order.
%
%   fname:        Name of the file to be opened. If the fname is omitted
%                 the user will be prompted to select a file. 
%                 DEFAULT: Will open Open File UI.
%
%   'read':       Will read the data in addition to the header information
%                 if user passes this argument.
%                 DEFAULT: will only read the header information.
%
%   'report':     Will show a summary report if user passes this argument.
%                 DEFAULT: will not show report.
%
%   'electrodes': User can specify which electrodes need to be read. The
%                 number of electrodes can be greater than or equal to 1
%                 and less than or equal to 128. The electrodes can be
%                 selected either by specifying a range (e.g. 20:45) or by
%                 indicating individual electrodes (e.g. 3,6,7,90) or both.
%                 This field needs to be preceded by the prefix 'e:'. See
%                 example for more details. If this option is selected the
%                 user will be promped for a CMP mapfile (see: KTUEAMapFile)
%                 provided by Blackrock Microsystems. This feature required
%                 KTUEAMapFile to be present in path.
%                 DEFAULT: will read all existing electrodes.
%
%   'channels':   User can specify which channels need to be read. The
%                 number of channels can be greater than or equal to 1
%                 and less than or equal to 128. The channels can be
%                 selected either by specifying a range (e.g. 20:45) or by
%                 indicating individual channels (e.g. 3,6,7,90) or both.
%                 This field needs to be preceded by the prefix 'c:'. See
%                 example for more details.
%                 DEFAULT: will read all existing analog channels.
%
%   'duration':   User can specify the beginning and end of the data
%                 segment to be read. If the start time is greater than the
%                 length of data the program will exit with an error
%                 message. If the end time is greater than the length of
%                 data the end packet will be selected for end of data. The
%                 user can specify the start and end values by comma 
%                 (e.g. [20,50]) or by a colon (e.g. [20:50]). To use this
%                 argument the user must specify the [electrodes] or the
%                 interval will be used for [electrodes] automatically.
%                 This field needs to be preceded by the prefix 't:'. 
%                 Note that if 'mode' is 'sample' the start duration cannot
%                 be less than 1. The duration is inclusive.
%                 See example for more details.
%                 DEFAULT: will read the entire file.
%
%   'mode':       The user can specify the mode of duration in [duration],
%                 such as 'sec', 'min', 'hour', or 'sample'. If 'sec' is
%                 specified the numbers in [duration] will correspond to
%                 the number of seconds. The same is true for 'min', 'hour'
%                 and 'sample'.
%                 DEFAULT: reads 'sample'.
%
%   'precision':  This will specify the precision for NSx file. If set to
%                 'double' the NSx data will be read as 'double' and if set
%                 to 'short', the NSx data will be read as 'int16' data
%                 type. While reading the file as 'short' may have a much
%                 smaller memory footprint and a faster read time, some 
%                 post data analysis such as multiplying the signal by a 
%                 factor that will make the data larger than (-32,768 to 
%                 32,767 -- refer to MATLAB documentation for more 
%                 information) may result in unexpected behavior. 
%                 Always use caution when using short. If you are not sure
%                 of what to use then do not specify this option.
%                 DEFAULT: will read data in 'int16'.
%
%   'skipfactor': This option will allow the user to read a decimated
%                 version of the data. The skipfactor will determine how
%                 many samples to skip. For example, if skipfactor is 2
%                 then every other sample is read. If skipfactor is 5 then
%                 every fifth sample is read. This is useful to briefly
%                 looking at the data in a large datafile when reading the
%                 entire dataset would overflow memory.
%                 DEFAULT: is set to 1, so every sample will be read.
%
%   OUTPUT:       Contains the NSx structure.
%
%   Example 1: 
%   openNSx('report','read','c:\data\sample.ns5', 'e:15:30', 't:3:10','min', 'p:short', 's:5');
%
%   or equivalently
%   openNSx('report','read','c:\data\sample.ns5', 'electrodes', 15:30, 'duration', 3:10, 'min', 'precision', 'short', 'skipfactor', 5);
%
%   In the example above, the file c:\data\sample.ns5 will be used. A
%   report of the file contents will be shown. The data will be read from
%   electrodes 15 through 50 in the 3-10 minute time interval. A decimated 
%   version of the datafile will be read, where only every 5th sample is read.
%   If any of the arguments above are omitted the default values will be used.
%
%   Example 2:
%   openNSx('read','c:15:30');
%
%   In the example above, the file user will be prompted for the file. The
%   file will be read using 'int16' precision as default. All time points 
%   of Only channels 15 through 30 will be read. If any of the arguments 
%   above are omitted the default values will be used.
%
%   Kian Torab
%   ktorab@blackrockmicro.com
%   Blackrock Microsystems
%   Version 4.0.1.0
%

%% Defining the NSx data structure and sub-branches.
NSx          = struct('MetaTags',[],'Data',[]);
NSx.MetaTags = struct('FileTypeID',[],'SamplingLabel',[],'ChannelCount',[],'SamplingFreq',[], 'TimeRes', [], ...
                      'ChannelID',[],'DateTime',[],'DateTimeRaw',[], 'Comment', [], 'FileSpec', [], ...
                      'Timestamp', [], 'DataPoints', [], 'openNSxver', [], 'Filename', [], 'FilePath', [], ...
                      'FileExt', [], 'HeaderOffset', []);

NSx.MetaTags.openNSxver = '4.0.0.3';

% Defining constants
ExtHeaderLength            = 66;

%% Validating the input arguments. Exit with error message if error occurs.
next = '';
for i=1:length(varargin)
    inputArgument = varargin{i};
    if strcmpi(next, 'channels')
        next = '';
        Chan = inputArgument;
    elseif strcmpi(next, 'electrodes')
        next = '';
        if exist('KTUEAMapFiel', 'file') == 2
            Mapfile = KTUEAMapFile;
            Elec = str2num(inputArgument); %#ok<ST2NM>
            for chanIDX = 1:length(Elec)
                Chan(chanIDX) = Mapfile.Electrode2Channel(Elec(chanIDX));
            end
            clear Elec;
        else
            disp('To read data by ''electrodes'' the function KTUEAMapFile needs to be in path.');
            clear variables;
            return;
        end
    elseif strcmpi(next, 'duration')
        next = '';
        StartPacket = min(inputArgument);
        EndPacket = max(inputArgument);
        if (EndPacket > 128 || StartPacket < 1)
             disp('The electrode number cannot be less than 1 or greater than 128.');
            if nargout; varargout{1} = []; end
            return;
        end
    elseif strcmpi(next, 'precision')
        next = '';
        precisionTypeRaw = inputArgument;
        switch precisionTypeRaw
			case 'int16'
				precisionType = '*int16=>int16';
            case 'short'
                precisionType = '*short=>short';
            case 'double'
                precisionType = '*int16';
            otherwise
                disp('Read type is not valid. Refer to ''help'' for more information.');
                if nargout; varargout{1} = []; end
                return;
        end
        clear precisionTypeRaw;
    elseif strcmpi(next, 'skipfactor')
        next = '';
        skipFactor = inputArgument;
    elseif strcmpi(inputArgument, 'channels')
        next = 'channels';
    elseif strcmpi(inputArgument, 'skipfactor')
        next = 'skipfactor';
    elseif strcmpi(inputArgument, 'electrodes')
        next = 'electrodes';
    elseif strcmpi(inputArgument, 'duration')
        next = 'duration';
    elseif strcmpi(inputArgument, 'precision')
        next = 'precision';
    elseif strcmpi(inputArgument, 'report')
        Report = inputArgument;
    elseif strcmpi(inputArgument, 'noread')
        ReadData = inputArgument;
    elseif strcmpi(inputArgument, 'read')
        ReadData = inputArgument;
    elseif strncmp(inputArgument, 't:', 2) && inputArgument(3) ~= '\' && inputArgument(3) ~= '/'
        colonIndex = find(inputArgument(3:end) == ':');
        StartPacket = str2num(inputArgument(3:colonIndex+1));
        EndPacket = str2num(inputArgument(colonIndex+3:end));    
        if min(inputArgument)<1 || max(inputArgument)>128
            disp('The electrode number cannot be less than 1 or greater than 128.');
            if nargout; varargout{1} = []; end
            return;
        end
        clear colonIndex;
    elseif strncmp(inputArgument, 'e:', 2) && inputArgument(3) ~= '\' && inputArgument(3) ~= '/'
        if exist('KTUEAMapFiel', 'file') == 2
            Mapfile = KTUEAMapFile;
            Elec = str2num(inputArgument(3:end)); %#ok<ST2NM>
            for chanIDX = 1:length(Elec)
                Chan(chanIDX) = Mapfile.Electrode2Channel(Elec(chanIDX));
            end
            clear Elec;
        else
            disp('To read data by ''electrodes'' the function KTUEAMapFile needs to be in path.');
            clear variables;
            return;
        end
    elseif strncmp(inputArgument, 's:', 2) && inputArgument(3) ~= '\' && inputArgument(3) ~= '/'
        skipFactor = str2num(inputArgument(3:end)); %#ok<ST2NM>
    elseif strncmp(inputArgument, 'c:', 2) && inputArgument(3) ~= '\' && inputArgument(3) ~= '/'
        Chan = str2num(inputArgument(3:end)); %#ok<ST2NM>
    elseif strncmp(varargin{i}, 'p:', 2) && inputArgument(3) ~= '\' && inputArgument(3) ~= '/'
        precisionTypeRaw = varargin{i}(3:end);
        switch precisionTypeRaw
			case 'int16'
				precisionType = '*int16=>int16';
            case 'short'
                precisionType = '*short=>short';
            case 'double'
                precisionType = '*int16';
            otherwise
                disp('Read type is not valid. Refer to ''help'' for more information.');
                if nargout; varargout{1} = []; end
                return;
        end
        clear precisionTypeRaw;
    elseif strfind(' hour min sec sample ', [' ' inputArgument ' ']) ~= 0
        TimeScale = inputArgument;
    else
        temp = inputArgument;
        if length(temp)>3 && strcmpi(temp(end-3),'.')
            fname = inputArgument;
            if exist(fname, 'file') ~= 2
                disp('The file does not exist.');
                if nargout; 
                    varargout{1} = []; 
                end
                return;
            end
        else
            disp(['Invalid argument ''' inputArgument ''' .']);
            if nargout; varargout{1} = []; end
            return;
        end
    end
end
clear next;

%% Popup the Open File UI. Also, process the file name, path, and extension
%  for later use, and validate the entry.
if ~exist('fname', 'var')
    [fname, path] = getFile('*.ns*', 'Choose a NSx file...');
    if fname == 0
        disp('No file was selected.');
        if nargout
            clear variables;
        end
        return;
    end
    fext = fname(end-3:end);
else
    [path,fname, fext] = fileparts(fname);
    fname = [fname fext];
    path  = [path '/'];
end
if fname==0
    if nargout; varargout{1} = []; end
    return; 
end

tic;

%% Give all input arguments a default value. All input argumens are
%  optional.
if ~exist('Report', 'var');        Report = 'noreport';    end
if ~exist('ReadData', 'var');      ReadData = 'noread';    end
if ~exist('StartPacket', 'var');   StartPacket = 0;        end
if ~exist('TimeScale', 'var');     TimeScale = 'sample';   end
if ~exist('precisionType', 'var'); precisionType = '*short=>short'; end
if ~exist('skipFactor', 'var');    skipFactor = 1;         end

if strcmp(Report, 'report')
    disp(['openNSx ' NSx.MetaTags.openNSxver]);
end

%% Reading Basic Header from file into NSx structure.
FID                        = fopen([path fname], 'r', 'ieee-le');
NSx.MetaTags.Filename     = fname;
NSx.MetaTags.FilePath     = path;
NSx.MetaTags.FileExt      = fext;
NSx.MetaTags.FileTypeID    = fread(FID, [1,8]   , '*char');
if strcmpi(NSx.MetaTags.FileTypeID, 'NEURALSG')
	NSx.MetaTags.FileSpec      = '2.1';
    NSx.MetaTags.SamplingLabel = fread(FID, [1,16]  , '*char');
    NSx.MetaTags.TimeRes       = 30000;
    NSx.MetaTags.SamplingFreq  = NSx.MetaTags.TimeRes / fread(FID, 1 , 'uint32=>double');
    ChannelCount               = fread(FID, 1       , 'uint32=>double');
    NSx.MetaTags.ChannelCount  = ChannelCount;
    NSx.MetaTags.ChannelID     = fread(FID, [ChannelCount 1], '*uint32');
	t                          = dir([path fname]);
	NSx.MetaTags.DateTime      = t.date;
elseif strcmpi(NSx.MetaTags.FileTypeID, 'NEURALCD')
    BasicHeader                = fread(FID, 306, '*uint8');
    NSx.MetaTags.FileSpec      = [num2str(double(BasicHeader(1))) '.' num2str(double(BasicHeader(2)))];
    HeaderBytes                = typecast(BasicHeader(3:6), 'uint32');
    NSx.MetaTags.SamplingLabel = char(BasicHeader(7:22))';
    NSx.MetaTags.Comment       = char(BasicHeader(23:278))';
    NSx.MetaTags.TimeRes       = double(typecast(BasicHeader(283:286), 'uint32'));
    NSx.MetaTags.SamplingFreq  = NSx.MetaTags.TimeRes / double(typecast(BasicHeader(279:282), 'uint32'));
    t                          = double(typecast(BasicHeader(287:302), 'uint16'));
    ChannelCount               = typecast(BasicHeader(303:306), 'uint32');
    NSx.MetaTags.ChannelCount  = ChannelCount;
    ExtendedHeader             = fread(FID, ChannelCount * ExtHeaderLength, '*uint8');
	if (fread(FID, 1, 'uint8') ~= 1)
		disp('header corrupted!');
		fclose(FID);
		if nargout; varargout{1} = []; end
		return;		
	end
    NSx.MetaTags.Timestamp     = fread(FID, 1, 'uint32');
    NSx.MetaTags.DataPoints    = fread(FID, 1, 'uint32');
    NSx.MetaTags.ChannelID     = zeros(ChannelCount, 1);
	%% Populating extended header information
	for headerIDX = 1:ChannelCount
		offset = double((headerIDX-1)*ExtHeaderLength);
		NSx.ElectrodesInfo(headerIDX).Type = char(ExtendedHeader((1:2)+offset))';
		if (~strcmpi(NSx.ElectrodesInfo(headerIDX).Type, 'CC'))
			disp('extended header not supported');
			fclose(FID);
			if nargout; varargout{1} = []; end
			return;			
		end
		NSx.ElectrodesInfo(headerIDX).ElectrodeID = typecast(ExtendedHeader((3:4)+offset), 'uint16');
        NSx.MetaTags.ChannelID(headerIDX) = NSx.ElectrodesInfo(headerIDX).ElectrodeID;
		NSx.ElectrodesInfo(headerIDX).Label = char(ExtendedHeader((5:20)+offset))';
		NSx.ElectrodesInfo(headerIDX).ConnectorBank = char(ExtendedHeader(21+offset) + ('A' - 1));
		NSx.ElectrodesInfo(headerIDX).ConnectorPin   = ExtendedHeader(22+offset);
		NSx.ElectrodesInfo(headerIDX).MinDigiValue   = typecast(ExtendedHeader((23:24)+offset), 'int16');
		NSx.ElectrodesInfo(headerIDX).MaxDigiValue   = typecast(ExtendedHeader((25:26)+offset), 'int16');
		NSx.ElectrodesInfo(headerIDX).MinAnalogValue = typecast(ExtendedHeader((27:28)+offset), 'int16');
		NSx.ElectrodesInfo(headerIDX).MaxAnalogValue = typecast(ExtendedHeader((29:30)+offset), 'int16');
		NSx.ElectrodesInfo(headerIDX).AnalogUnits    = char(ExtendedHeader((31:46)+offset))';
		NSx.ElectrodesInfo(headerIDX).HighFreqCorner = typecast(ExtendedHeader((47:50)+offset), 'uint32');
		NSx.ElectrodesInfo(headerIDX).HighFreqOrder  = typecast(ExtendedHeader((51:54)+offset), 'uint32');
		NSx.ElectrodesInfo(headerIDX).HighFilterType = typecast(ExtendedHeader((55:56)+offset), 'uint16');
		NSx.ElectrodesInfo(headerIDX).LowFreqCorner  = typecast(ExtendedHeader((57:60)+offset), 'uint32');
		NSx.ElectrodesInfo(headerIDX).LowFreqOrder   = typecast(ExtendedHeader((61:64)+offset), 'uint32');
		NSx.ElectrodesInfo(headerIDX).LowFilterType  = typecast(ExtendedHeader((65:66)+offset), 'uint16');
	end
	clear ExtendedHeader;
	%% Parsing and validating FileSpec and DateTime variables
	NSx.MetaTags.DateTimeRaw = t.';
	NSx.MetaTags.DateTime = [num2str(t(2)) '/'  num2str(t(4)) '/' num2str(t(1))...
		' ' datestr(t(3), 'dddd') ' ' num2str(t(5)) ':'  ...
		num2str(t(6)) ':'  num2str(t(7)) '.' num2str(t(8))] ;
	clear t;	
else
    disp('This version of openNSx can only read File Specs 2.1, 2.2 and 2.3');
    disp(['The selected file spec is ' NSx.MetaTags.FileSpec '.']);
    fclose(FID);
    clear variables;
    return;
end
fHeader = ftell(FID);
NSx.MetaTags.HeaderOffset = fHeader;
fseek(FID, 0, 'eof');
fData = ftell(FID);
fseek(FID, fHeader, 'bof');

%% Removing extra garbage characters from the Comment field.
NSx.MetaTags.Comment(find(NSx.MetaTags.Comment==0,1):end) = 0;

%% Adjusts StartPacket and EndPacket based on what time setting (sec, min,
%  hour, or packets) the user has indicated in the input argument.
NSx.MetaTags.NumofPackets = (fData-fHeader)/(2*ChannelCount);
if isempty(NSx.MetaTags.DataPoints)
    NSx.MetaTags.DataPoints = NSx.MetaTags.NumofPackets;
end
if ~exist('EndPacket', 'var')
    EndPacket = NSx.MetaTags.NumofPackets;
end
switch TimeScale
    case 'sec'
        StartPacket = StartPacket * NSx.MetaTags.SamplingFreq;
        EndPacket = EndPacket * NSx.MetaTags.SamplingFreq;
    case 'min'
        StartPacket = StartPacket * NSx.MetaTags.SamplingFreq * 60;
        EndPacket = EndPacket * NSx.MetaTags.SamplingFreq * 60;
    case 'hour'
        StartPacket = StartPacket * NSx.MetaTags.SamplingFreq * 3600;
        EndPacket = EndPacket * NSx.MetaTags.SamplingFreq * 3600;
    case 'sample'
        if (StartPacket > 0)
            StartPacket = StartPacket - 1;
        end
        EndPacket = EndPacket - 1;
end
% from now StartPacket and EndPacket are in terms of Samples and are zero-based
clear TimeScale

if EndPacket >= NSx.MetaTags.DataPoints
    disp('This version cannot read paused files after pause');
    fclose(FID);
    if nargout; NSx = []; end
    return;    
end

%% Validate StartPacket and EndPacket to make sure they do not exceed the
%  length of packets in the file. If EndPacket is over then the last packet
%  will be set for EndPacket. If StartPacket is over then will exist with an
%  error message.
if EndPacket >= NSx.MetaTags.NumofPackets
    if StartPacket >= NSx.MetaTags.NumofPackets
        disp('The starting packet is greater than the total data duration.');
		fclose(FID);
        if nargout; varargout{1} = []; end
        return;
    end
    disp('The time interval specified is longer than the data duration.');
    disp('Last data point will be used instead.');
    if strcmp(Report, 'report')
        disp('Press enter to continue...');
        pause;
    end
    EndPacket = NSx.MetaTags.NumofPackets - 1;
else
DataLength = EndPacket - StartPacket + 1;

%% Displaying a report of basic file information and the Basic Header.
if strcmp(Report, 'report')
    disp( '*** FILE INFO **************************');
    disp(['File Path          = '  path]);
    disp(['File Name          = '  fname   ]);
	disp(['File Version       = '  NSx.MetaTags.FileSpec   ]);
    disp(['Duration (seconds) = '  num2str(double(NSx.MetaTags.NumofPackets/NSx.MetaTags.SamplingFreq))]);
    if (NSx.MetaTags.NumofPackets > NSx.MetaTags.DataPoints)
        disp(['Paused Data Points = '  num2str(NSx.MetaTags.DataPoints)]);
    else
        disp(['Total Data Points  = '  num2str(double(NSx.MetaTags.NumofPackets))]);
    end
    disp(' ');
    disp( '*** BASIC HEADER ***********************');
    disp(['File Type ID       = '          NSx.MetaTags.FileTypeID      ]);
    disp(['Sample Frequency   = '  num2str(double(NSx.MetaTags.SamplingFreq))         ]);
    disp(['Electrodes Read    = '  num2str(double(NSx.MetaTags.ChannelCount))   ]);
    disp(['Data Point Read    = '  num2str(double(DataLength))]);
end

%% Read data points
if ~exist('Chan', 'var'); Chan = 1:ChannelCount; end

if strcmp(ReadData, 'read')
    ReadElec = max(Chan)-min(Chan)+1;
    if max(Chan) > NSx.MetaTags.ChannelCount
        fprintf(2,'\nThe channel selected is greater than the maximum number of channels in the file.\n');
        fclose(FID);
        if nargout; varargout{1} = []; end
        return;
    end
    fseek(FID, StartPacket * 2 * ChannelCount + fHeader, 'bof');
    fseek(FID, (min(Chan)-1) * 2, 'cof');
    NSx.Data = fread(FID, [ReadElec DataLength], [num2str(ReadElec) precisionType], (ChannelCount-ReadElec)*2 + ChannelCount*(skipFactor-1)*2);
end

%% Removing unwanted channels
channelRange = min(Chan):max(Chan);
deleteChannels = setdiff(channelRange,Chan) - min(Chan) + 1;
NSx.Data(deleteChannels,:) = [];

%% If user does not specify an output argument it will automatically create
%  a structure.
outputName = ['NS' fext(4)];
if (nargout == 0),
    assignin('caller', outputName, NSx);
else
    varargout{1} = NSx;
end

if strcmp(Report, 'report')
	disp(['The load time for ' outputName ' file was ' num2str(toc, '%0.1f') ' seconds.']);
end
fclose(FID);

end