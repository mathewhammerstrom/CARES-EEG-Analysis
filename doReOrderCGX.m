function [EEG] = doReOrderCGX(EEG,fileName)
%Loads in (preferrably filtered) CGX data, displays some characteristics,
%and prompts you to identify which are the front channels so they can be
%removed. 

data = EEG.data;

subplot(4,1,1);plot(data(1,1:5000))
hold on;
ylim([-50,50])
subplot(4,1,2);plot(data(2,1:5000))
hold on;
ylim([-50,50])
subplot(4,1,3);plot(data(3,1:5000))
hold on;
ylim([-50,50])
subplot(4,1,4); plot(data(4,1:5000))
hold on;
ylim([-50,50])

varCheck = var(data,0,2);
disp(varCheck)
disp(fileName)

chan = 1;
chan2 = 4;

close all;
label1 = EEG.chanlocs(chan).labels;
label2 = EEG.chanlocs(chan2).labels;

[EEG] = doRemoveChannels(EEG,{label1,label2},EEG.chanlocs);
