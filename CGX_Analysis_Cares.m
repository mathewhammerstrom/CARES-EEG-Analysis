clear all;
close all;
clc;

%% Prepare Participant File %%
EXCEL =table({1},{1},{1}); %Load in the summary file with experiment characteristics (CA number, condition, etc.)
EXCEL.Properties.VariableNames = {'File','Output','Artifacts'};

rootdir = uigetdir('','Select the Folder with all of your EEG folders in it'); %Where you want to read data from
outputDir = uigetdir('','Select the Folder where you want analyzed data to go'); %Where you want the data to go

%% Pre-Processing Parameters
nbEEGChan = 4;
chanNames = {'Fp1','TP9','TP10','Fp2'};
artifactParameter = 60;

markers = {'S101', 'S102','S103'};

%% Load in XDF Folders %%

% Scroll through folders and find any containing relevant files
filelist = dir(fullfile(rootdir, '**/*.*'));  %get list of files and folders in any subfolder
% ^ Use a forward slash (/) for Mac, Use a back slash (\) for windows)
files = filelist(~[filelist.isdir]);

% Check to make sure we're only looking at the xdf files
newCount = 0;
for counter = 1:length(files)
    name = strsplit(files(counter).name,'.');
    if strcmp(name{2},'xdf') ==1
        newCount = newCount+1;
        newFiles(newCount) = files(counter);
    end
end

%% Main Pre-Processing Loop
for counter = 1:length(newFiles)

    
    fileName = newFiles(counter).name; %Set Filename for current participant
    EXCEL.File(counter)= {fileName};
    pathName = newFiles(counter).folder; %Set Pathname for current participant
    
    cd(pathName);
    
    [EEG] = doLoadCGX(pathName,fileName,nbEEGChan,chanNames,2,1,0); %Load in CGX data with set parameters
    x = [];
    
%     [EEG] = doRemoveChannels(EEG, {'Fp1','Fp2'}, EEG.chanlocs);
    
    [EEG] = doFilter(EEG,2,15,2,60,EEG.srate); %Filter data, 2Hz to 30hz Bandpass 2nd order butterworth with 60Hz notch
    
    [EEG] = doSegmentData(EEG,markers,[-200, 1000]); %Segment data 200 ms before and 600 ms after stimulus
        
    [EEG] = doIncreasePEERSNR(EEG,2); %Increase signal to noise ratio by concatenating Tp9, Tp10

    [EEG] = doBaseline(EEG,[-200,0]); %Baseline correction
    
    [EEG] = doArtifactRejection(EEG,'Difference',artifactParameter); %Artifact rejection with set parameter, difference method
    
    [EEG] = doRemoveEpochs(EEG,EEG.artifact.badSegments,0); %Remove segments identified by artifact rejection
    
    [ERP] = doERP(EEG,markers,0); %Create ERPs from remaining segments
    
    outputName = ['OUTPUT_',fileName,'.mat'];
    EXCEL.Output(counter) = {outputName}; %Write into table how we are saving our output files
    save(fullfile(outputDir,outputName),'ERP'); %Save individual data
    
    
    
    allERP(:,:,:,counter) = ERP.data; %Create grand average ERP (Channels x Time x Condition x Participants)
    artifacts(counter,:) = sum(EEG.artifact.badSegments,2)/length(EEG.artifact.badSegments); %Keep track of how many segments you removed
    EXCEL.Artifacts(counter) = {artifacts(counter,:)};
       
end

cd(rootdir);
grandERP = nanmean(allERP,4); %ERP averaged across participants (4th dimension)


%% Plot Data
collapsedERP = nanmean(allERP,4);
collapsedERP = nanmean(collapsedERP,3);

subplot(2,1,1);
plot(ERP.times,grandERP(1,:,1),'LineWidth',3);
hold on;
plot(ERP.times,grandERP(1,:,2),'LineWidth',3);
hold on;
plot(ERP.times,grandERP(1,:,3),'LineWidth',3);
hold on;
% plot(ERP.times,collapsedERP(1,:),'k','LineWidth',3);
title('Concatenated TP9 and TP10')
legend('Meth','Neutral','Negative','Collapsed')

subplot(2,1,2);
bar(artifacts);
title('Artifact %s')

erpName =  ['ERP_AllParticipants'];
save(fullfile(outputDir,erpName),'grandERP') %Write this data into the summary sheet

%% Quantify %%

channel = 1;
[tempMax, p3loc] = max(collapsedERP(channel,251:401)); %Find max in 300ms-600ms post Stimulus
timeRange = [p3loc(channel)-25+251:p3loc(channel)+25+251]; %Make a 50ms window around it
channelName = ERP.chanlocs(channel).labels;

for participants = 1:size(allERP,4)
    for conditions = 1:3
        [p3Max(conditions)] = mean(allERP(channel,timeRange,conditions,participants),2); %FInd mean in our time range
        fdata(participants, conditions) = p3Max(conditions); %Save for each condition into simple array
        EXCEL(participants, conditions+3) = array2table(p3Max(conditions)); %Save for each condition into our table
    end
end

outputName =  ['OUTPUT_AllParticipants'];
save(fullfile(outputDir,outputName),'fdata') %Write this data into the summary sheet

writetable(EXCEL,fullfile(outputDir,outputName)) %Write this data into the summary sheet
