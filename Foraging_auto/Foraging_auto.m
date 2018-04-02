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
function Sarah
% This protocol is a starting point for a foraging task with two ports.
% Here animals just learn that water is available at two (opposing) ports.
% Written by Sarah Starosta 05/2016.
%
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
    S.GUI.RewardAmount = 4; %ul
     S.GUI.RewardDelay = 0; %ul
end

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);

%% Define trials
MaxTrials = 1000;
tpt       = 20;
TrialTypes = ceil(rand(1,1000)*1);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);
BpodNotebook('init');

%% Main trial loop
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    R = GetValveTimes(S.GUI.RewardAmount, [1 3]); LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
  
    sma = NewStateMatrix(); % Assemble state matrix
    sma = AddState(sma, 'Name', 'WaitForPoke', ...
        'Timer', tpt,...
        'StateChangeConditions', {'Tup', 'exit','Port1In', 'LeftRewardDelay', 'Port3In', 'RightRewardDelay'},...
        'OutputActions', {});
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
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'PWM3', 255});
       sma = AddState(sma, 'Name', 'Drinkingleft', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'PWM1', 255});
    
    
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
       UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.BeingUsed == 0
        return
    end
    
 
    
    
    
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

% for x=1: length(SessionData.RawEvents.Trial)
% ~isnan(Data.RawEvents.Trial{x}.States.LeftReward(1))
% end



