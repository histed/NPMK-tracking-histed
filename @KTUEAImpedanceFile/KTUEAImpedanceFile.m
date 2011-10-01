classdef KTUEAImpedanceFile

% Plots a graphical representation of the impedance data collected by
% Cerebus and saved in a text file.
%
% Usage:
%
%   plotImpedances(mapfile)
%
%   WHERE:
%
%   mapfile:    Is the mapfile structure obtained with mapfileLoader
%               function that maps the electrodes to channel numbers. If
%               mapfile is not provided then a default map will be used.
%
%   Kian Torab
%   kian.torab@utah.edu
%   Department of Bioengineering
%   University of Utah
%   Version 1.0.1 - April 29, 2010

    properties (Hidden, SetAccess = private, GetAccess = private)
        chanCount    = 96;
        impedanceDataValues = NaN(1, 96);
        Mapfile
        fileHandle
        pathHandle
    end
    methods(Hidden)
        function obj = KTUEAImpedanceFile(Mapfile)
            folderManager = KTFolderManager;
            if ~exist('Mapfile', 'var')
                obj.Mapfile = KTUEAMapFile;
            else
                obj.Mapfile = Mapfile;
            end
            if ~obj.Mapfile.isValid; return; end;
%             fileHandle = '2010-02-19-R03067-UEAback-Impedances.txt';
%             pathHandle = 'Z:\SYNC D Drive\Data\Frik\UEA\Back\Impedences\';
            Mapfilename = obj.Mapfile.getFilename;
            if ~isempty(strfind(Mapfilename, 'Back'))
                [obj.fileHandle obj.pathHandle] = uigetfile(folderManager.DefaultLoadImpedancesBackLocation, 'Open an impedance file...');
            else
                [obj.fileHandle obj.pathHandle] = uigetfile(folderManager.DefaultLoadImpedancesFrontLocation, 'Open an impedance file...');
            end
            if ~obj.fileHandle; disp('No file was selected.'); return; end;
            impedanceDataCell = importdata([obj.pathHandle obj.fileHandle], ' ', 200);
            impedanceDataCell(1:9) = [];
            impedanceDataCell(97:end) = [];
            impedanceDataCellParsed = regexp(impedanceDataCell, '\t', 'split');
            for i = 1:size(impedanceDataCellParsed, 1)
                impedanceSingleCell = impedanceDataCellParsed{i,:}(2);
                impedanceSingleText = impedanceSingleCell{:};
                obj.impedanceDataValues(i) = str2double(impedanceSingleText(1:end-4));
            end
        end
    end
    methods
        function FilePath = PathName(obj)
            FilePath = obj.pathHandle;
        end
        function FileName = Filename(obj)
            FileName = obj.fileHandle;
        end
        function validFlag = isValid(obj)
            if any(isnan(obj.getChannelImpedances)) 
                validFlag = 0;
            else
                validFlag = 1;
            end
        end
        function impedanceDataValues = getChannelImpedances(obj)
            impedanceDataValues = obj.impedanceDataValues;
        end
        function impedanceDataValue = getChannelImpedance(obj, chanNum)
            if ~exist('chanNum', 'var')
                disp('Channel number is a required argument.');
                return;
            end
            impedanceDataValue = obj.impedanceDataValues(chanNum);
        end
        function plotImpedances(obj)
            redThreshold = 800;
            yelThreshold = 100;
            plotFigure = KTFigure;
            plotFigure.EnlargeFigure;
            plotFigure.MakeBackgroundWhite;
            hold on;
            for channelIDX = 1:obj.chanCount
                if obj.impedanceDataValues(channelIDX) > redThreshold
                    spColor = [1,0,0];
                    fColor  = [1,1,1];
                elseif obj.impedanceDataValues(channelIDX) < redThreshold && obj.impedanceDataValues(channelIDX) > yelThreshold
                    spColor = [0,0,0];
                    fColor  = [1,1,1];
                elseif obj.impedanceDataValues(channelIDX) < yelThreshold
                    spColor = [1,1,0];
                    fColor  = [0,0,0];
                end
                obj.Mapfile.GenerateChannelSubplot(channelIDX);
                obj.Mapfile.GenerateChannelSubplotNames(channelIDX, fColor);
                text(0.05, 0.7, [num2str(obj.impedanceDataValues(channelIDX)) ' kOhm'], 'Color', fColor, 'FontSize', 10, 'FontWeight', 'bold');
                axis on;
                obj.Mapfile.setAxisBackgroundColor(spColor);
                obj.Mapfile.setAxesColor(spColor);
            end
            hold off;
            plotFigure.ShowFigure;
        end
        function colorPlotBackground(obj)
            for channelIDX = 1:obj.chanCount
                obj.Mapfile.GenerateChannelSubplot(channelIDX);
                axis on;
                obj.Mapfile.setAxisBackgroundColor([0,obj.impedanceDataValues(channelIDX)/max(max(obj.impedanceDataValues)),0]);        
            end
        end
        function plotImpedancesComparison(obj)
            changeThreshold = 0.2;
            yelThreshold = 100;
            secImpedanceFile = KTUEAImpedanceFile(obj.Mapfile);
            secImpedanceValues = secImpedanceFile.getChannelImpedances;
            plotFigure = KTFigure;
            plotFigure.EnlargeFigure;
            plotFigure.MakeBackgroundWhite;
            hold on;
            for channelIDX = 1:obj.chanCount
                percentChange = (obj.impedanceDataValues(channelIDX) - secImpedanceValues(channelIDX))/obj.impedanceDataValues(channelIDX);
                if abs(percentChange)  > changeThreshold && percentChange > 0
                    % Lime Green -- If impedance is increased by more 
                    % than threshold.
                    if abs(percentChange) > 2 * changeThreshold
                        spColor = [34,139,34] ./255;
                        fColor  = [1,1,1];
                    else
                        spColor = [154,205,50] ./255;
                        fColor  = [0,0,0];
                    end
                elseif abs(percentChange) > changeThreshold && percentChange < 0
                    % Chocolate orange -- If impedance is dropped by more 
                    % than threshold.
                    if abs(percentChange) > 2 * changeThreshold
                        spColor = [210,105,30] ./255;
                        fColor  = [1,1,1];
                    else
                        spColor = [245,222,179] ./255;
                        fColor  = [0,0,0];
                    end
                else
                    % Honeydew -- If threshold change is less than
                    % threshold.
                    spColor = [240,255,240] ./255;
                    fColor  = [0,0,0];
                end
                obj.Mapfile.GenerateChannelSubplot(channelIDX);
                patchHandle = patch([0.5, 0.5, 0, 0], [1, 0, 0, 1], spColor);
                obj.Mapfile.GenerateChannelSubplotNames(channelIDX, fColor);
                text(0.05, 0.7, ['1: ' num2str(obj.impedanceDataValues(channelIDX)) ' kOhm'], 'Color', fColor, 'FontSize', 10, 'FontWeight', 'bold');
                text(0.05, 0.5, ['2: ' num2str(secImpedanceValues(channelIDX)) ' kOhm'], 'Color', fColor, 'FontSize', 10, 'FontWeight', 'bold');
            end
            hold off;
            plotFigure.ShowFigure;
        end
    end
end