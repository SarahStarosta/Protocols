


%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABIL6TY or FITNESS FOR A PARTICULAR PURPOSE.
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


global BpodSystem
clc
%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.Subject           = 555; %ul
    S.GUI.RewardAmount      = 12; %ul
    S.GUI.RewardDelay       = 5;
    S.GUI.block             = 10; %Sfter how many trials should bridge change
    S.GUI.depright          = 0.4; % 1 means no depletion at all
    S.GUI.depleft           = 0.6;
    S.GUI.MaxTrials         = 100000000;
end

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);
TrialTypes = ceil(rand(1,S.GUI.MaxTrials)*1);
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);
%% Define trials
StartRewardLeft= shuffle(repmat(2:S.GUI.RewardAmount ,1,150));
StartRewardRight= shuffle(repmat(2:S.GUI.RewardAmount,1,150));
block=S.GUI.block; % after how many trials should the bridge change?
changebridge = zeros(1,10000000);
%changebridge(block:block:100000000)=1;
howmany=length(find(changebridge==1))
bridgepos= repmat([130; 180; 230],ceil(howmany/3),1);

count=1;
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
    end
    if RightAmount(currentTrial)< 1 % check what is reasonable here; 0.02 is circa 0.7um
        RightAmount(currentTrial)= 0;
        RightValveTime(currentTrial) = GetValveTimes(RightAmount(currentTrial), [3]);
    elseif LeftAmount(currentTrial)< 1 %
        LeftAmount(currentTrial)= 0;
        LeftValveTime(currentTrial) =  GetValveTimes(LeftAmount(currentTrial), [1]);
    end
    sma = AddState(sma, 'Name', 'WaitForPoke', ...
        'Timer', 5,...
        'StateChangeConditions', {'Tup', 'WaitForPoke','Port1In', 'LeftRewardDelay', 'Port3In', 'RightRewardDelay'},...
        'OutputActions', {});
    
    
    
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
    sma = AddState(sma, 'Name', 'Drinkingright', ...
        'Timer', S.GUI.RewardDelay,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Drinkingleft', ...
        'Timer',S.GUI.RewardDelay ,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});
    
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    BpodSystem.Data.LeftValveTime(currentTrial)     = LeftValveTime(currentTrial) ; % Adds the left valvetime to the current data
    BpodSystem.Data.RightValveTime(currentTrial)    = RightValveTime(currentTrial) ; % Adds the left valvetime to the current data
    BpodSystem.Data.LeftAmount(1)                   = LeftAmount(1) ; % Adds the left valvetime to the current data
    BpodSystem.Data.RightAmount(1)                  = RightAmount(1) ; % Adds the left valvetime to the current data
    BpodSystem.Data.TrialSettings(currentTrial)     = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
    BpodSystem.Data.changebridge                    = changebridge;
    BpodSystem.Data.bridgepos                       = bridgepos;
    BpodSystem.Data.subject                         = S.GUI.Subject;
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        BpodSystem.Data.TrialSettings(currentTrial)     = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.LeftValveTime(currentTrial)     = LeftValveTime(currentTrial) ; % Adds the left valvetime to the current data
        BpodSystem.Data.RightValveTime(currentTrial)    = RightValveTime(currentTrial) ; % Adds the left valvetime to the current data
        
        
        if currentTrial>0
            if  isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial}.States.LeftReward(1))==0 % was the animal in the left port?
                BpodSystem.Data.LeftAmount(currentTrial)        = LeftAmount(currentTrial) ; % write down the amount sampled
                BpodSystem.Data.RightAmount(currentTrial)       = NaN;
            elseif   isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial}.States.RightReward(1))==0 %was the animal in the right port?
                BpodSystem.Data.RightAmount(currentTrial)       = RightAmount(currentTrial) ; % write down for this port
                BpodSystem.Data.LeftAmount(currentTrial)        = NaN;
            end
        end
    end
    
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.BeingUsed == 0
        return
    end
    
    P=BpodSystem.Data;
    
end

function UpdateSideOutcomePlot(TrialTypes, Data)
global BpodSystem
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

% for x=1: length(Data.RawEvents.Trial)
%     countsright(x)= ~isnan(Data.RawEvents.Trial{x}.States.RightReward(1));
%     countsleft(x)= ~isnan(Data.RawEvents.Trial{x}.States.LeftReward(1));
% end
% figure(5)
% clf('reset')
% subplot(2,2, [1 2])
% plot(cumsum(countsright)),hold on
% plot(cumsum(countsleft),'r'),hold on
% xlabel('trials')
% ylabel('cumulative enters')
% legend('right','left')
% ylim([0 length(Data.RawEvents.Trial)])
% ylim([0 length(Data.RawEvents.Trial)])
% 
% start=1;
% 
% subplot(2,2, [3 4])
% 
% plot(Data.LeftAmount,'-rs','MarkerSize',3), hold on
% plot(Data.RightAmount, '-ks','MarkerSize',3)
% ylim([-1 10])
% ylabel('amount sampled [µl]')
% xlabel('trials')
% if length(Data.RawEvents.Trial)>1
%     legend(num2str(Data.TrialSettings(1,1).GUI.depright),num2str(Data.TrialSettings(1,1).GUI.depleft))
% end
% wnan=find(isnan(Data.RightAmount(1:end)))-1;
% leaveright=Data.RightAmount(wnan(2:end));
% meanleaveright=nanmean(leaveright(start:end));
% semleaveright=nanstd(leaveright(start:end));
% 
% wnan=find(isnan(Data.LeftAmount(1:end)))-1;
% leaveleft=Data.LeftAmount(wnan(2:end));
% meanleaveleft=nanmean(leaveleft(start:end));
% semleaveleft=nanstd(leaveleft(start:end));
% 
% 
% 
% subplot(2,2, [3 4])
% xlength=get(gca,'XLim');
% try
%     errorshade(1:xlength(2),ones(1,xlength(2))*meanleaveright,semleaveright,'LineColor','k'),hold on
%     errorshade(1:xlength(2),ones(1,xlength(2))*meanleaveleft,semleaveleft, 'ShadeColor',[0.9 0 0.1],'LineColor','r')
%     
% end





