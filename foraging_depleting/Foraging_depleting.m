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
function foraging_depleting
% This protocol is  a foraging task with two ports, which are depleting at different rates.
% %
% SETUP
% You will need:
% - A Bpod MouseBox (or equivalent) configured with 2 ports.
% > Connect the left port in the box to Bpod Port#1.
% > % > Connect the right port in the box to Bpod Port#3.
% > Make sure the liquid calibration tables for ports 1 and 3 are there


global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount      = 6; %ul
    S.GUI.RewardDelay       = 2.5;
    S.GUI.ReEnter           = 3; %how often are they allowed to reenter before only the other port is
    S.GUI.depleft           = 0.8; % 1 means no depletion at all
    S.GUI.depright          = 0.4;
    S.GUI.MaxTrials         = 1000;
end

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);

%% Define trials

TrialTypes = ceil(rand(1,1000)*1);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);
BpodNotebook('init');
R = GetValveTimes(S.GUI.RewardAmount, [1 3]); LeftValveTime(1) = R(1); RightValveTime(1) = R(2); % Update reward amounts
%% Main trial loop
for currentTrial = 1:S.GUI.MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    R = GetValveTimes(S.GUI.RewardAmount, [1 3]); LeftValveTime(1) = R(1); RightValveTime(1) = R(2); % Update reward amounts
    LeftAmount(1)= S.GUI.RewardAmount;
    RightAmount(1)= S.GUI.RewardAmount;
    sma = NewStateMatrix(); % Assemble state matrix
    
    
    % check if animal has been in this port before
    if currentTrial>1
        if isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial-1}.States.RightReward(1))==0%has it been to the right port on the last trial?
            LeftAmount(currentTrial)= S.GUI.RewardAmount;
            LeftValveTime(currentTrial) = R(1);
            RightAmount(currentTrial)=  RightAmount(currentTrial-1)* S.GUI.depright
            RightValveTime(currentTrial) = GetValveTimes(RightAmount(currentTrial), [3]); % Update reward amounts
            
        elseif isnan(BpodSystem.Data.RawEvents.Trial{1,currentTrial-1}.States.LeftReward(1))==0 % has it been to the left port on the last trial?
            RightAmount(currentTrial)= S.GUI.RewardAmount;
            RightValveTime(currentTrial) = R(2);
            LeftAmount(currentTrial)=  LeftAmount(currentTrial-1)* S.GUI.depleft
            LeftValveTime(currentTrial) = GetValveTimes(LeftAmount(currentTrial), [1]); % Update reward amounts
            
        else
            LeftAmount(currentTrial)= S.GUI.RewardAmount;
            RightAmount(currentTrial)= S.GUI.RewardAmount;
            LeftValveTime(currentTrial) =  R(1);
            RightValveTime(currentTrial) = R(2);
        end
    end
    
    
    
    if RightValveTime(currentTrial) < 0 % check what is reasonable here; 0.02 is circa 0.7um
        
        sma = AddState(sma, 'Name', 'WaitForLeftPoke', ...
            'Timer', 5,...
            'StateChangeConditions', {'Tup', 'WaitForLeftPoke','Port1In', 'LeftRewardDelay'},...
            'OutputActions', {})
        
    elseif LeftValveTime(currentTrial) < 0 % check what is reasonable here; 0.02 is circa 0.7um
        
        sma = AddState(sma, 'Name', 'WaitForRightPoke', ...
            'Timer', 5,...
            'StateChangeConditions', {'Tup', 'WaitForRightPoke','Port3In', 'RightRewardDelay'},...
            'OutputActions', {});
        
    else
        
        sma = AddState(sma, 'Name', 'WaitForPoke', ...
            'Timer', 5,...
            'StateChangeConditions', {'Tup', 'WaitForPoke','Port1In', 'LeftRewardDelay', 'Port3In', 'RightRewardDelay'},...
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
        'Timer', LeftValveTime(currentTrial),...
        'StateChangeConditions', {'Tup', 'Drinkingleft'},...
        'OutputActions', {'ValveState', 1});
    sma = AddState(sma, 'Name', 'RightReward', ...
        'Timer', RightValveTime(currentTrial),...
        'StateChangeConditions', {'Tup', 'Drinkingright'},...
        'OutputActions', {'ValveState', 4});
    sma = AddState(sma, 'Name', 'Drinkingright', ...
        'Timer', 2,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Drinkingleft', ...
        'Timer', 2,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});
    
    
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
     BpodSystem.Data.TrialTypes(currentTrial)        = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        BpodSystem.Data.LeftValveTime(currentTrial)     = LeftValveTime(currentTrial) ; % Adds the left valvetime to the current data
        BpodSystem.Data.RightValveTime(currentTrial)    = RightValveTime(currentTrial) ; % Adds the left valvetime to the current data
        BpodSystem.Data.LeftAmount(currentTrial)        = LeftAmount(currentTrial) ; % Adds the left valvetime to the current data
        BpodSystem.Data.RightAmount(currentTrial)       = RightAmount(currentTrial) ; % Adds the left valvetime to the current data
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        
        BpodSystem.Data.TrialSettings(currentTrial)      = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial)        = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        BpodSystem.Data.LeftValveTime(currentTrial)     = LeftValveTime(currentTrial) ; % Adds the left valvetime to the current data
        BpodSystem.Data.RightValveTime(currentTrial)    = RightValveTime(currentTrial) ; % Adds the left valvetime to the current data
        BpodSystem.Data.LeftAmount(currentTrial)        = LeftAmount(currentTrial) ; % Adds the left valvetime to the current data
        BpodSystem.Data.RightAmount(currentTrial)       = RightAmount(currentTrial) ; % Adds the left valvetime to the current data
        
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



