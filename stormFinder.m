%%stormFinder
%   Given an structure of ASOS data, return start time, end time, hour of
%   peak intensity, and data for all storms in the season. Individual
%   storms determined by 2-hour gaps.
%
%   ASOS 5-minute data does not record snow liquid water, and snow liquid
%   water is usually unreliable on this timescale anyway. We approximate
%   peak intensity from the weather codes. All weather code entries are
%   assigned a numerical intensity score (iScore): '+' = 3, none = 2, '-' =
%   1. For storms of sufficient length, the event is scored by hour. The
%   hours are then summed individually, and the hour with the highest
%   iScore is considered the hour of peak intensity.
%
%   General form: [storms] = stormFinder(ASOS)
%
%   Input:
%   ASOS: ASOS data structure, see ASOSimportFiveMin or ASOSimportManyFiveMin.
%
%   Output:
%   storms: structure containing the storm information. The 'all'
%   substructure contains every storm with precipitation codes from the
%   input structure. The 'filtered' substructure requires that events have
%   a total iScore above 15. This is an attempt to omit minimal-impact
%   trace events.
%
%   Written by: Daniel Hueholt
%   North Carolina State University
%   Research Assistant at Environment Analytics
%   Version Date: 6/16/2020
%   Last Major Revision: 6/16/2020
%


function [storms] = stormFinder(ASOS)
presentWeather = {ASOS.PresentWeather};

precipCode = ["SN","BLSN","PL","DZ","FZDZ","RA","FZRA","SG","GS"]; % all possible weather codes corresponding to precipitation ordered usefully
weather = contains(presentWeather,precipCode);
% Where weather is 1, there is at least one precip code hit
% Where weather is 0, precip is not occurring
[~,weatherInd,~] = find(weather); % Find indices where precip occurs
weatherInd = weatherInd';

findGaps = diff(weatherInd); %Look for gaps in the indices where precip occurs
gapLog = findGaps>24; %If the gap is larger than 24 indices, then it's longer than 2 hours
[gapInd,~,~] = find(gapLog);
weatherData = ASOS(weather);

codesOnly = {weatherData.PresentWeather};
heavy = contains(codesOnly,'+');
light = contains(codesOnly,'-');
[~,heavyInd,~] = find(heavy);
[~,lightInd,~] = find(light);
iScore = ones(length(codesOnly),1)*2;
iScore(heavyInd) = 3;
iScore(lightInd) = 1;

fc = 1;
for wq = 1:length(gapInd)-1
    allStorms(wq).data = weatherData(gapInd(wq)+1:gapInd(wq+1)-1); %#ok
    allStorms(wq).startTime = allStorms(wq).data(1).Datetime; %#ok
    allStorms(wq).endTime = allStorms(wq).data(end).Datetime; %#ok
    allStorms(wq).iScoreArr = iScore(gapInd(wq)+1:gapInd(wq+1)-1); %#ok
    iScoreScalar = sum(allStorms(wq).iScoreArr);
    allStorms(wq).iScore = iScoreScalar; %#ok
    
    if iScoreScalar > 15
        filterStorms(fc).data = allStorms(wq).data; %#ok
        filterStorms(fc).startTime = allStorms(wq).startTime; %#ok
        filterStorms(fc).endTime = allStorms(wq).endTime; %#ok
        filterStorms(fc).iScoreArr = allStorms(wq).iScoreArr; %#ok
        filterStorms(fc).iScore = iScoreScalar; %#ok
        
        stormDuration = filterStorms(fc).endTime-filterStorms(fc).startTime;
        if stormDuration>hours(1)
            activeDt = [allStorms(wq).data.Datetime]';
            activeiScore = [allStorms(wq).iScoreArr];
            activeHour = activeDt.Hour;
            allHours = unique(activeHour);
            for hq = 1:length(allHours)
                indHour = activeHour==allHours(hq);
                hour(hq).datetime = activeDt(indHour);
                hour(hq).iScoreArr = activeiScore(indHour);
                hour(hq).iScore = sum(hour(hq).iScoreArr);
            end
            [~,maxInd] = max([hour.iScore]);
            peakIntensity.Hour = hour(maxInd).datetime(1).Hour;
            peakIntensity.datetime = hour(maxInd).datetime;
            peakIntensity.iScoreArr = hour(maxInd).iScoreArr;
            peakIntensity.iScore = sum(peakIntensity.iScoreArr);
            filterStorms(fc).peak = peakIntensity; %#ok
            filterStorms(fc).peakHourStart = peakIntensity.datetime(1);
        else
            filterStorms(fc).peak = [];
            filterStorms(fc).peakHourStart = [];
        end
        clear activeDt; clear activeiScore; clear activeHour;
        clear allHours; clear hour; clear indHour; clear peakIntensity;
        fc = fc+1;
        
    end
    
end

% Make final output structure
storms.all = allStorms;
storms.filtered = filterStorms;

end