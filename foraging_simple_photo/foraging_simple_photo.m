%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
function foraging_xtimes
% This protocol is a starting point for a foraging task with two ports.
% Here animals just learn that water is available at two (opposing) ports, at each port it will get x- times a reward.
% Written by Sarah Starosta 05/2016.
%
% SETUP
% You will need:
% - A Bpod MouseBox (or equivalent) configured with 2 ports.
% > Connect the left port in the box to Bpod Port#1.
% > % > Connect the right port in the box to Bpod Port#3.
% > Make sure the liquid calibration tables for ports 1 and 3 are there


global BpodSystem S nidaq

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 3; %ul
    S.GUI.RewardDelay = 1;
    S.GUI.ReEnter = 4; %ul
    S.GUI.LED1_Amp =2.6; %yellow, 2.6
    S.GUI.LED2_Amp = 0.5; % blue, 0.5
    S.GUI.LED1_Freq = 211;
    S.GUI.LED2_Freq = 531;
    S.GUI.Modulation=1;
    S.GUI.DrinkingTime = 5;
    S.GUI.PRE= 1;
    S.GUI.NidaqDuration=200;
    S.GUI.DecimateFactor=610;
    S.GUI.NidaqSamplingRate=6100;
    S.GUI.BaselineBegin=0.01;
    S.GUI.BaselineEnd = 2;
end

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);
S = BpodParameterGUI('sync', S);

% Define trials
MaxTrials = 1000;
TrialTypes = ceil(rand(1,1000)*1);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);
BpodNotebook('init');

%% NIDAQ Initialization
Nidaq_photometry('ini');

%% Main trial loop
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    R = GetValveTimes(S.GUI.RewardAmount, [1 3]); LeftValveTime =R(1); RightValveTime = R(2); % Update reward amounts
    
    sma = NewStateMatrix(); % Assemble state matrix
    
    if currentTrial > S.GUI.ReEnter
        clear countsright countleft
        for k=1:S.GUI.ReEnter
            countsright(k)= ~isnan(P.RawEvents.Trial{currentTrial-k}.States.RightReward(1));
            countsleft(k)= ~isnan(P.RawEvents.Trial{currentTrial-k}.States.LeftReward(1));
        end
        
        if sum(countsright)== S.GUI.ReEnter
            sma = AddState(sma, 'Name', 'PRE', ...
                'Timer', S.GUI.PRE,...
                'StateChangeConditions', {'Tup', 'WaitForLeftPoke','Port5In', 'crossover'},...
                'OutputActions', {});
            
            sma = AddState(sma, 'Name', 'WaitForLeftPoke', ...
                'Timer', 60,...
                'StateChangeConditions', {'Tup', 'WaitForLeftPoke','Port1In', 'LeftRewardDelay','Port5In', 'crossover'},...
                'OutputActions', {});
            
        elseif sum(countsleft)== S.GUI.ReEnter
            sma = AddState(sma, 'Name', 'PRE', ...
                'Timer', S.GUI.PRE,...
                'StateChangeConditions', {'Tup', 'WaitForRightPoke','Port5In', 'crossover'},...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'WaitForRightPoke', ...
                'Timer', 60,...
                'StateChangeConditions', {'Tup', 'WaitForRightPoke','Port3In', 'RightRewardDelay','Port5In', 'crossover'},...
                'OutputActions', {});
            
        else
            sma = AddState(sma, 'Name', 'PRE', ...
                'Timer', S.GUI.PRE,...
                'StateChangeConditions', {'Tup', 'WaitForPoke','Port5In', 'crossover'},...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'WaitForPoke', ...
                'Timer', 5,...
                'StateChangeConditions', {'Tup', 'exit','Port1In', 'LeftRewardDelay', 'Port3In', 'RightRewardDelay','Port5In', 'crossover'},...
                'OutputActions', {});
        end
    else
        sma = AddState(sma, 'Name', 'PRE', ...
            'Timer', S.GUI.PRE,...
            'StateChangeConditions', {'Tup', 'WaitForPoke','Port5In', 'crossover'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'WaitForPoke', ...
            'Timer', 5,...
            'StateChangeConditions', {'Tup', 'WaitForPoke','Port1In', 'LeftRewardDelay', 'Port3In', 'RightRewardDelay','Port5In', 'crossover'},...
            'OutputActions', {});
    end
    
    
    sma = AddState(sma, 'Name', 'LeftRewardDelay', ...
        'Timer', S.GUI.RewardDelay,...
        'StateChangeConditions', {'Tup', 'LeftReward','Port1Out','LeftReward'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'RightRewardDelay', ...
        'Timer', S.GUI.RewardDelay,...
        'StateChangeConditions', {'Tup', 'RightReward','Port3Out','RightReward'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'LeftReward', ...
        'Timer', LeftValveTime,...
        'StateChangeConditions', {'Tup', 'Drinkingleft'},...
        'OutputActions', {'ValveState', 1});
    sma = AddState(sma, 'Name', 'RightReward', ...
        'Timer', RightValveTime,...
        'StateChangeConditions', {'Tup', 'Drinkingright'},...
        'OutputActions', {'ValveState', 4});
    sma = AddState(sma, 'Name', 'Drinkingright', ...
        'Timer', S.GUI.DrinkingTime,...
        'StateChangeConditions', {'Tup', 'WaitForPoke','Port5In', 'crossover'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Drinkingleft', ...
        'Timer', S.GUI.DrinkingTime,...
        'StateChangeConditions', {'Tup', 'WaitForPoke','Port5In', 'crossover'},...
        'OutputActions', {});
    
    sma = AddState(sma, 'Name', 'crossover', ...
        'Timer', 2,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});
    
    SendStateMatrix(sma);
    
    %% NIDAQ Get nidaq ready to start
    
    Nidaq_photometry('WaitToStart');
    tic
    RawEvents = RunStateMatrix;
    toc
    %% NIDAQ Stop acquisition and save data in bpod structure
    
    [PhotoData,Photo2Data]=Nidaq_photometry('Stop');
    
    
    %%
    %    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data          BpodSystem.Data.NidaqData{currentTrial}=PhotoData; % adds photometry data from Photo1 to bpoddata
        BpodSystem.Data.NidaqData{currentTrial}=PhotoData;% adds photometry data from Photo1 to bpoddata
        BpodSystem.Data.Nidaq2Data{currentTrial}=Photo2Data;% adds photometry data from Photo1 to bpoddata
        tic
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        toc
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.BeingUsed == 0
        return
    end
    
    P=BpodSystem.Data;
    
    
end

function UpdateSideOutcomePlot(TrialTypes, Data)
global BpodSystem nidaq S
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.LeftReward(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.RightReward(1))
        Outcomes(x) = 0;
    else
        Outcomes(x) = 3;
    end
end
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',Data.nTrials+1,2-TrialTypes,Outcomes);
%% final plot

for x=1: length(Data.RawEvents.Trial)
    countsright(x)= ~isnan(Data.RawEvents.Trial{x}.States.RightReward(1));
    countsleft(x)= ~isnan(Data.RawEvents.Trial{x}.States.LeftReward(1));
end
figure(5)
plot(cumsum(countsright)),hold on
plot(cumsum(countsleft),'r'),hold on
xlabel('trials')
ylabel('cumulative enters')
legend('right','left')
ylim([0 length(Data.RawEvents.Trial)])
ylim([0 length(Data.RawEvents.Trial)])

% photometry plot
%%
currentTrial =BpodSystem.Data.nTrials;
if ~isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial}.States.LeftReward(1,1)) || ~isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial}.States.RightReward(1,1))
figure(6)
Photo2Data=BpodSystem.Data.Nidaq2Data{currentTrial};
PhotoData=BpodSystem.Data.NidaqData{currentTrial};

if ~isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial}.States.LeftReward(1,1))
    StateToZero='LeftReward';
elseif ~isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial}.States.RightReward(1,1))
    StateToZero='RightReward';
end

[currentNidaq2,Raw2]=Online_NidaqDemod(Photo2Data(:,1),Photo2Data(:,2),S.GUI.LED2_Freq,S.GUI.LED2_Amp,StateToZero,currentTrial);
[currentNidaq1,Raw1]=Online_NidaqDemod(PhotoData(:,1),PhotoData(:,2),S.GUI.LED1_Freq,S.GUI.LED1_Amp,StateToZero,currentTrial);
Raw1(:,2)=Raw1(:,2)+5;
subplot(1,2,1); hold off;
plot(currentNidaq1(:,1),currentNidaq1(:,3),'r'); hold on;
plot(currentNidaq2(:,1),currentNidaq2(:,3),'g');
subplot(1,2,2); hold off
plot(Raw1(:,2),'r'); hold on;
plot(Raw2(:,2),'g');
end

% currentTrial =length(BpodSystem.Data.Nidaq2Data);
% S.GUI.NidaqDuration = 1; %what is the length?
% % Freq_LED2=SessionData.TrialSettings(1).GUI.LED2_Freq;
% % Amp_LED2 =SessionData.TrialSettings(1).GUI.LED2_Amp;d