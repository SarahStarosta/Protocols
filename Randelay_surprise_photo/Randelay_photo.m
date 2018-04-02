%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLcC, Sound Beach, New York, USA

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
function Foraging_rand_bridge
% This protocol is  a foraging task with two ports, which are depleting at different rates.
% %
% SETUP
% You will need:
% - A Bpod MouseBox (or equivalent) configured with 2 ports.
% > Connect the left port in the box to Bpod Port#1.
% > % > Connect the right port in the box to Bpod Port#3.
% > Make sure the liquid calibration tables for ports 1 and 3 are there


global BpodSystem S nidaq
clc
%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.Subject           = 555;
    S.GUI.RewardAmount      = [12]; %ul
    S.GUI.RewardDelay       = 4;
    S.Pre                   = 2;
    S.GUI.ChangeOver        = 0;%changeover
    S.GUI.block             = 100000000000; %Sfter how many trials should bridge change
    S.GUI.depleft           = 0.8; % 1 means no depletion at all
    S.GUI.depright          = 0.8;
    S.GUI.MaxTrials         = 300;
    S.GUI.randomDelay       = 0;
    S.GUI.Bridge            = 0;
    S.GUI.Drugs             = 0;
    S.GUI.LED1_Amp = 0.5; %Blue 0.5
    S.GUI.LED2_Amp = 3; %Yellow
    S.GUI.LED1_Freq = 211;
    S.GUI.LED2_Freq = 531;
    S.GUI.Modulation=1;
    S.GUI.DrinkingTime = 1;
    S.GUI.PRE= 2;
    S.GUI.NidaqDuration=200;
    S.GUI.DecimateFactor=610;
    S.GUI.NidaqSamplingRate=6100;
    S.GUI.BaselineBegin=0.01;
    S.GUI.BaselineEnd = 2;
end

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);
TrialTypes = ceil(rand(1,1000)*1);
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);
%% Define trials
StartRewardLeft= shuffle(repmat(S.GUI.RewardAmount ,1,S.GUI.MaxTrials));
StartRewardRight= shuffle(repmat(S.GUI.RewardAmount,1,S.GUI.MaxTrials));
block=S.GUI.block; % after how many trials should the bridge change?
changebridge = zeros(1,1000);
changebridge(block:block:1000)=1;
howmany=length(find(changebridge==1))
bridgepos= repmat([130; 180; 230],ceil(howmany/3),1);

if S.GUI.randomDelay  ==1
    for k=1:S.GUI.MaxTrials
        delays(k) = exprnd(S.GUI.RewardDelay);
        while delays(k)>10 | delays(k)<1
            delays(k) = exprnd(S.GUI.RewardDelay);
        end
        
    end
else
    delays = ones(1,S.GUI.MaxTrials)*S.GUI.RewardDelay ;
end
count=1;

%% Define surprise reward trials
surpriseTrials=ones(1,20);
%for xs=1: S.GUI.MaxTrials/50 % max define 50 trials at once
surpriseTrials=[surpriseTrials randomOrder(3,S.GUI.MaxTrials,'maxrepeat',20,'ratio',[0.8 0.1 0.1])];
%end
%% NIDAQ Initialization
Nidaq_photometry('ini');
%% Main trial loop
for currentTrial = 1:S.GUI.MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    LeftValveTime(1) = GetValveTimes(StartRewardLeft(1), [1]);
    RightValveTime(1) = GetValveTimes(StartRewardRight(1), [1]); % Update reward amounts
    LeftAmount(1)= StartRewardLeft(1);
    RightAmount(1)= StartRewardRight(1);
    sma = NewStateMatrix(); % Assemble state matrix
    
    % check if animal has been in this port before
    if currentTrial>1
        if surpriseTrials(currentTrial)==1; % no surprise
            if isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial-1}.States.RightReward(1))==0%has it been to the right port on the last trial?
                LeftAmount(currentTrial)= StartRewardLeft(currentTrial);
                LeftValveTime(currentTrial) = GetValveTimes(StartRewardLeft(currentTrial), [1]);
                RightAmount(currentTrial)=  RightAmount(currentTrial-1)* S.GUI.depright;
                RightValveTime(currentTrial) = GetValveTimes(RightAmount(currentTrial), [3]); % Update reward amounts
                
            elseif isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial-1}.States.LeftReward(1))==0 % has it been to the left port on the last trial?
                RightAmount(currentTrial)=  StartRewardRight(currentTrial);
                RightValveTime(currentTrial) = GetValveTimes(StartRewardRight(currentTrial), [1]);
                LeftAmount(currentTrial)=  LeftAmount(currentTrial-1)* S.GUI.depleft;
                LeftValveTime(currentTrial) = GetValveTimes(LeftAmount(currentTrial), [1]); % Update reward amounts
                
            else
                LeftAmount(currentTrial)=StartRewardLeft(currentTrial);
                RightAmount(currentTrial)= StartRewardRight(currentTrial);
                LeftValveTime(currentTrial) =  GetValveTimes(LeftAmount(currentTrial), [1]);
                RightValveTime(currentTrial) = GetValveTimes(RightAmount(currentTrial), [3]);
            end
        elseif surpriseTrials(currentTrial)==2; % positive surprise            
                surpriseTrials(currentTrial+1:currentTrial+10)=1;
                surpriseTrials(currentTrial+11:end)=randomOrder(3,length(surpriseTrials(currentTrial+11:end)),'maxrepeat',20,'ratio',[0.8 0.1 0.1]);
            if isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial-1}.States.RightReward(1))==0%has it been to the right port on the last trial?
                LeftAmount(currentTrial)= StartRewardLeft(currentTrial);
                LeftValveTime(currentTrial) = GetValveTimes(StartRewardLeft(currentTrial), [1]);
                RightAmount(currentTrial)=  RightAmount(currentTrial-1)* 2; % get double the amount
                RightValveTime(currentTrial) = GetValveTimes(RightAmount(currentTrial), [3]); % Update reward amounts
                
            elseif isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial-1}.States.LeftReward(1))==0 % has it been to the left port on the last trial?
                RightAmount(currentTrial)=  StartRewardRight(currentTrial);
                RightValveTime(currentTrial) = GetValveTimes(StartRewardRight(currentTrial), [1]);
                LeftAmount(currentTrial)=  LeftAmount(currentTrial-1)*2;% get double the amount
                LeftValveTime(currentTrial) = GetValveTimes(LeftAmount(currentTrial), [1]); % Update reward amounts
                
            end
            elseif surpriseTrials(currentTrial)==3; % negative surprise
                
                surpriseTrials(currentTrial+1:currentTrial+10)=1;
                surpriseTrials(currentTrial+11:end)=randomOrder(3,length(surpriseTrials(currentTrial+11:end)),'maxrepeat',20,'ratio',[0.8 0.1 0.1]);
            if isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial-1}.States.RightReward(1))==0%has it been to the right port on the last trial?
                LeftAmount(currentTrial)= StartRewardLeft(currentTrial);
                LeftValveTime(currentTrial) = GetValveTimes(StartRewardLeft(currentTrial), [1]);
                RightAmount(currentTrial)=  RightAmount(currentTrial-1)* 0.5; % get half the amount
                RightValveTime(currentTrial) = GetValveTimes(RightAmount(currentTrial), [3]); % Update reward amounts
                
            elseif isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial-1}.States.LeftReward(1))==0 % has it been to the left port on the last trial?
                RightAmount(currentTrial)=  StartRewardRight(currentTrial);
                RightValveTime(currentTrial) = GetValveTimes(StartRewardRight(currentTrial), [1]);
                LeftAmount(currentTrial)=  LeftAmount(currentTrial-1)*0.5;% get half the amount
                LeftValveTime(currentTrial) = GetValveTimes(LeftAmount(currentTrial), [1]); % Update reward amounts                
            end
            
            
        end
        if RightAmount(currentTrial)< 1 % check what is reasonable here; 0.02 is circa 0.7um
            RightAmount(currentTrial)= 0;
            RightValveTime(currentTrial) = GetValveTimes(RightAmount(currentTrial), [3]);
        elseif LeftAmount(currentTrial)< 1 %
            LeftAmount(currentTrial)= 0;
            LeftValveTime(currentTrial) =  GetValveTimes(LeftAmount(currentTrial), [1]);
        end
        
        % Bridge?
        if changebridge(currentTrial)==1
            count=count+1;
            SerialPort = serial('COM1', 'BaudRate', 115200, 'DataBits', 8, 'StopBits', 1, 'Timeout', 1, 'DataTerminalReady', 'off');
            % Send new servo position:
            fopen(SerialPort)
            pause (2)
            fwrite(SerialPort,['A' bridgepos (count)]) % Note: range = 130-250
            fclose(SerialPort); % Terminate connection:
            % give BNC input
            sma = AddState(sma, 'Name', 'ChangeBridge', ...
                'Timer', 3,...
                'StateChangeConditions', {'Tup', 'BridgeStop'},...
                'OutputActions', {'BNCState', 1}); %%% give BNC output
            sma = AddState(sma, 'Name', 'BridgeStop', ...
                'Timer', 1,...
                'StateChangeConditions', {'Tup', 'WaitForPoke'},...
                'OutputActions', {'BNCState', 0}); %%% stop BNC output
        end
        
        %     if currentTrial>2
        %         if isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial-1}.States.LeftReward(1))==0 % has it been to the left port on the last trial?
        %             sma = AddState(sma, 'Name', 'Delayrightpoke', ...
        %                 'Timer',  S.GUI.ChangeOver,...
        %                 'StateChangeConditions', {'Tup', 'Pre','Port1In', 'LeftRewardDelay',},...
        %                 'OutputActions', {});
        %         elseif isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial-1}.States.RightReward(1))==0%has it been to the right port on the last trial?
        %             sma = AddState(sma, 'Name', 'Delayleftpoke', ...
        %                 'Timer',  S.GUI.ChangeOver,...
        %                 'StateChangeConditions', {'Tup', 'Pre','Port3In', 'RightRewardDelay',},...
        %                 'OutputActions', {});
        %         end
        %
        %     end
        sma = AddState(sma, 'Name', 'Pre', ...
            'Timer', S.Pre,...
            'StateChangeConditions', {'Tup', 'WaitForPoke'},...
            'OutputActions', {});
        
        
        sma = AddState(sma, 'Name', 'WaitForPoke', ...
            'Timer', 5,...
            'StateChangeConditions', {'Tup', 'WaitForPoke','Port1In', 'LeftRewardDelay', 'Port3In', 'RightRewardDelay'},...
            'OutputActions', {});
        
        sma = AddState(sma, 'Name', 'LeftRewardDelay', ...
            'Timer', 0,...
            'StateChangeConditions', {'Tup', 'LeftReward','Port1Out','LeftReward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'RightRewardDelay', ...
            'Timer', 0,...
            'StateChangeConditions', {'Tup', 'RightReward','Port3Out','RightReward'},...
            'OutputActions', {});
        
        sma = AddState(sma, 'Name', 'LeftReward', ...
            'Timer', LeftValveTime(currentTrial),...
            'StateChangeConditions', {'Tup', 'Drinkingleft'},...
            'OutputActions', {'ValveState', 1});
        sma = AddState(sma, 'Name', 'RightReward', ...
            'Timer', RightValveTime(currentTrial),...
            'StateChangeConditions', {'Tup', 'Drinkingright'},...
            'OutputActions', {'ValveState', 4});
        
        %     if currentTrial>2
        %         if isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial-1}.States.LeftReward(1))==0 % has it been to the left port on the last trial?
        %             sma = AddState(sma, 'Name', 'Drinkingright', ...
        %                 'Timer', delays(currentTrial)+ S.GUI.ChangeOver,...
        %                 'StateChangeConditions', {'Tup', 'exit'},...
        %                 'OutputActions', {});
        %             sma = AddState(sma, 'Name', 'Drinkingleft', ...
        %                 'Timer', delays(currentTrial),...
        %                 'StateChangeConditions', {'Tup', 'exit'},...
        %                 'OutputActions', {});
        %
        %         elseif isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial-1}.States.RightReward(1))==0%has it been to the right port on the last trial?
        %             sma = AddState(sma, 'Name', 'Drinkingleft', ...
        %                 'Timer', delays(currentTrial)+ S.GUI.ChangeOver,...
        %                 'StateChangeConditions', {'Tup', 'exit'},...
        %                 'OutputActions', {});
        %             sma = AddState(sma, 'Name', 'Drinkingright', ...
        %                 'Timer', delays(currentTrial),...
        %                 'StateChangeConditions', {'Tup', 'exit'},...
        %                 'OutputActions', {});
        %         end
        %     else
        sma = AddState(sma, 'Name', 'Drinkingright', ...
            'Timer', delays(currentTrial),...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'Drinkingleft', ...
            'Timer', delays(currentTrial),...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {});
        
        
        %     sma = AddState(sma, 'Name', 'crossover', ...
        %         'Timer', 0.1,...
        %         'StateChangeConditions', {'Tup', 'exit'},...
        %         'OutputActions', {});
        %     end
        
        SendStateMatrix(sma);
        
        %% NIDAQ Get nidaq ready to start
        
        Nidaq_photometry('WaitToStart');
        tic
        RawEvents = RunStateMatrix;
        toc
        %% NIDAQ Stop acquisition and save data in bpod structure
        
        [PhotoData,Photo2Data]=Nidaq_photometry('Stop');
        
        
        
        % RawEvents = RunStateMatrix;
        BpodSystem.Data.LeftValveTime(currentTrial)     = LeftValveTime(currentTrial) ; % Adds the left valvetime to the current data
        BpodSystem.Data.RightValveTime(currentTrial)    = RightValveTime(currentTrial) ; % Adds the left valvetime to the current data
        BpodSystem.Data.LeftAmount(1)                   = LeftAmount(1) ; % Adds the left valvetime to the current data
        BpodSystem.Data.RightAmount(1)                  = RightAmount(1) ; % Adds the left valvetime to the current data
        BpodSystem.Data.TrialSettings(currentTrial)     = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.changebridge                    = changebridge;
        BpodSystem.Data.bridgepos                       = bridgepos;
        BpodSystem.Data.subject                         = S.GUI.Subject;
        BpodSystem.Data.delays                          = delays;
        BpodSystem.Data.suprise                         = surpriseTrials;
        
        if ~isempty(fieldnames(RawEvents)) % If trial data was returned
            BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
            BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
            
            
            BpodSystem.Data.TrialSettings(currentTrial)     = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
            BpodSystem.Data.LeftValveTime(currentTrial)     = LeftValveTime(currentTrial) ; % Adds the left valvetime to the current data
            BpodSystem.Data.RightValveTime(currentTrial)    = RightValveTime(currentTrial) ; % Adds the left valvetime to the current data
            BpodSystem.Data.NidaqData{currentTrial}=PhotoData;% adds photometry data from Photo1 to bpoddata
            BpodSystem.Data.Nidaq2Data{currentTrial}=Photo2Data;% adds photometry data from Photo1 to bpoddata
            
            %if currentTrial>0
            if  isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial}.States.LeftReward(1))==0 % was the animal in the left port?
                BpodSystem.Data.LeftAmount(currentTrial)        = LeftAmount(currentTrial) ; % write down the amount sampled
                BpodSystem.Data.RightAmount(currentTrial)       = NaN;
            elseif   isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial}.States.RightReward(1))==0 %was the animal in the right port?
                BpodSystem.Data.RightAmount(currentTrial)       = RightAmount(currentTrial) ; % write down for this port
                BpodSystem.Data.LeftAmount(currentTrial)        = NaN;
            end
            %end
        end
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
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
        
        [TdTom,TdTomRaw]=Online_NidaqDemod(Photo2Data(:,1),Photo2Data(:,2),S.GUI.LED2_Freq,S.GUI.LED2_Amp,StateToZero,currentTrial);
        [GCaMP,GCaMPRaw]=Online_NidaqDemod(PhotoData(:,1),PhotoData(:,2),S.GUI.LED1_Freq,S.GUI.LED1_Amp,StateToZero,currentTrial);
        GCaMPRaw(:,2)=GCaMPRaw(:,2)+5;
        subplot(2,2,1); hold off;
        plot(GCaMP(:,1),GCaMP(:,3),'g'); hold on;
        plot(TdTom(:,1),TdTom(:,3),'r','LineWidth',2);
        subplot(2,2,2); hold off
        plot(GCaMPRaw(:,2),'g'); hold on;
        plot(TdTomRaw(:,2),'r');
        subplot(2,2,3); hold off
        plot(Data.LeftAmount), hold on
        plot(Data.RightAmount,'r'),
        ylabel('water amount')
        xlabel('trial')
        legend('LeftAmount', 'RightAmount')
        onset=find(TdTom(:,1)>0,1,'first');
        try
            Data.forcorr(currentTrial,1)=max(TdTom(onset:end,3));
            if ~isnan(Data.RightAmount(currentTrial))
                Data.forcorr(currentTrial,2)=Data.RightAmount(currentTrial);
            else
                Data.forcorr(currentTrial,2)=Data.LeftAmount(currentTrial);
            end
        end
        try
            subplot(2,2,4)
            plot(Data.forcorr(:,1),Data.forcorr(:,2),'*'),hold on
            ylabel('water amount')
            xlabel('peak response')
        end
        %isline
    end
    
    % currentTrial =length(BpodSystem.Data.Nidaq2Data);
    % S.GUI.NidaqDuration = 1; %what is the length?
    % % Freq_LED2=SessionData.TrialSettings(1).GUI.LED2_Freq;
    % % Amp_LED2 =SessionData.TrialSettings(1).GUI.LED2_Amp;d