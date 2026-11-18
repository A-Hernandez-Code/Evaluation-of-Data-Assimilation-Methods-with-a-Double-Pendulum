%UI Configuration Setup
function [useSim,useMeas,...
    base,ensTrial,covTrial,noiseTrial,...
    useUKF,useEKF,useEnKF,...
    nTrials,nTrialsUKF,nTrialsEKF,nTrialsEnKF,...
    measFreqList,neList,covList,noiseStdList,...
    changeQ,changeR,changeP] = setupRun()

    %Main UI Window
    fig = uifigure(...
        'Name','Run Setup',...
        'Position',[500 350 650 380],...
        'KeyPressFcn',@(src,event) keyPress(event));

    %Sub Data Window
    dataBG = uibuttongroup(fig,...
        'Title','Data Source',...
        'Position',[15 215 190 145]);

    uiradiobutton(dataBG,...
        'Text','Simulation',...
        'Position',[15 90 150 22]);

    uiradiobutton(dataBG,...
        'Text','Measurement',...
        'Position',[15 65 150 22]);

    uiradiobutton(dataBG,...
        'Text','Both',...
        'Position',[15 40 150 22]);

    %Sub Case Window
    caseBG = uibuttongroup(fig,...
        'Title','Case',...
        'Position',[215 215 240 145]);

    baseButton = uiradiobutton(caseBG,...
        'Text','Base',...
        'Position',[15 90 180 22]);

    ensButton = uiradiobutton(caseBG,...
        'Text','Ensemble Size',...
        'Position',[15 65 180 22]);

    covButton = uiradiobutton(caseBG,...
        'Text','Covariance',...
        'Position',[15 40 180 22]);

    noiseButton = uiradiobutton(caseBG,...
        'Text','Measurement Noise',...
        'Position',[15 15 180 22]);

    %Sub Filter Window
    filterPanel = uipanel(fig,...
        'Title','Filters',...
        'Position',[465 215 170 145]);

    ukfCheck = uicheckbox(filterPanel,...
        'Text','UKF',...
        'Position',[15 90 100 22],...
        'Value',true);

    ekfCheck = uicheckbox(filterPanel,...
        'Text','EKF',...
        'Position',[15 65 100 22],...
        'Value',true);

    enkfCheck = uicheckbox(filterPanel,...
        'Text','EnKF',...
        'Position',[15 40 100 22],...
        'Value',true);

    %Sub Case Settings Window
    settingsPanel = uipanel(fig,...
        'Title','Case Settings',...
        'Position',[15 55 620 145]);

    simTrialLabel = uilabel(settingsPanel,...
    'Text','Simulation Trials:',...
    'Position',[15 85 145 22]);
    simTrialField = uieditfield(settingsPanel,'numeric',...
        'Position',[165 85 50 22],...
        'Value',25);
   
    ukfTrialLabel = uilabel(settingsPanel,...
        'Text','UKF Meas Trials:',...
        'Position',[235 85 105 22]);
    ukfTrialField = uieditfield(settingsPanel,'numeric',...
        'Position',[340 85 50 22],...
        'Value',1);
    
    ekfTrialLabel = uilabel(settingsPanel,...
        'Text','EKF Meas Trials:',...
        'Position',[410 85 105 22]);    
    ekfTrialField = uieditfield(settingsPanel,'numeric',...
        'Position',[515 85 50 22],...
        'Value',1);
    
    enkfTrialLabel = uilabel(settingsPanel,...
        'Text','EnKF Meas Trials:',...
        'Position',[15 85 145 22]);    
    enkfTrialField = uieditfield(settingsPanel,'numeric',...
        'Position',[165 85 50 22],...
        'Value',25);

    measFreqLabel = uilabel(settingsPanel,...
        'Text','Measurement Rate (Hz):',...
        'Position',[15 25 150 22]);
    measFreqField = uieditfield(settingsPanel,'text',...
        'Position',[170 25 100 22],...
        'Value','10 20 50 100');
    measFreqField.Tooltip = ...
        'Enter measurement frequencies in Hz seperated by spaces, e.g. 10 20 50 100';
    measFreqHelp = uibutton(settingsPanel,...
        'Text','?',...
        'Position',[280 25 22 22],...
        'Tooltip',...
        'Enter measurement frequencies in Hz seperated by spaces, e.g. 10 20 50 100');

    neLabel = uilabel(settingsPanel,...
    'Text','Ensemble Sizes:',...
    'Position',[15 55 150 22],...
    'Visible','off');
    neField = uieditfield(settingsPanel,'text',...
        'Position',[170 55 100 22],...
        'Value','5 10 25 50 100',...
        'Visible','off');   
    neHelp = uibutton(settingsPanel,...
        'Text','?',...
        'Position',[280 55 22 22],...
        'Tooltip','Enter ensemble sizes separated by spaces, e.g. 5 10 25 50 100',...
        'Visible','off');

    covValueLabel = uilabel(settingsPanel,...
    'Text','Covariance Multipliers:',...
    'Position',[15 55 150 22],...
    'Visible','off');
    covValueField = uieditfield(settingsPanel,'text',...
        'Position',[170 55 100 22],...
        'Value','0.1 0.5 1 2 10',...
        'Visible','off');  
    covValueHelp = uibutton(settingsPanel,...
        'Text','?',...
        'Position',[280 55 22 22],...
        'Tooltip','Enter multipliers for the selected baseline covariance separated by spaces, e.g. 0.1 0.5 1 2 10',...
        'Visible','off');

    covSelectLabel = uilabel(settingsPanel,...
    'Text','Covariance to Vary:',...
    'Position',[365 55 130 22],...
    'Visible','off');
    covBG = uibuttongroup(settingsPanel,...
        'BorderType','none',...
        'Position',[485 52 130 28],...
        'Visible','off');
    qButton = uiradiobutton(covBG,...
        'Text','Q',...
        'Position',[5 3 35 22],...
        'Value',true);    
    rButton = uiradiobutton(covBG,...
        'Text','R',...
        'Position',[45 3 35 22]);    
    pButton = uiradiobutton(covBG,...
        'Text','P0',...
        'Position',[85 3 40 22]);

    noiseStdLabel = uilabel(settingsPanel,...
    'Text','Noise Std. Dev.:',...
    'Position',[15 55 150 22],...
    'Visible','off');
    noiseStdField = uieditfield(settingsPanel,'text',...
        'Position',[170 55 100 22],...
        'Value','0.01 0.0316228 0.05 0.1 0.15 0.2 0.25 0.3',...
        'Visible','off');    
    noiseStdHelp = uibutton(settingsPanel,...
        'Text','?',...
        'Position',[280 55 22 22],...
        'Tooltip','Enter measurement noise standard deviations separated by spaces, e.g. 0.01 0.05 0.1',...
        'Visible','off');

    %Callbacks
    dataBG.SelectionChangedFcn = @(src,event) updateCases();
    caseBG.SelectionChangedFcn = @(src,event) updateCase();

    %Confirm/Continue Button
    uibutton(fig,...
        'text','Continue',...
        'Position',[535 15 100 30],...
        'ButtonPushedFcn',@(btn,event) validateSetup());

    updateCases();
    uiwait(fig);

    %Get selections
    selectedSource = dataBG.SelectedObject.Text;
    selectedCase = caseBG.SelectedObject.Text;

    %Set selections
    %Parameter Initialization
    nTrials = 0;
    nTrialsUKF = 0;
    nTrialsEKF = 0;
    nTrialsEnKF = 0;

    base = false;
    ensTrial = false;
    covTrial = false;
    noiseTrial = false;

    measFreqList = [];
    neList = [];
    covList = [];
    noiseStdList = [];

    changeQ = false;
    changeR = false;
    changeP = false;

    %Sim/Meas Flag
    switch selectedSource
        case 'Simulation'
            useSim = true;
            useMeas = false;
        case 'Measurement'
            useSim = false;
            useMeas = true;
        case 'Both'
            useSim = true;
            useMeas = true;
    end

    %Case Flags
    switch selectedCase
        case 'Base'
            base = true;
        case 'Ensemble Size'
            ensTrial = true;
            neList = str2double(strsplit(strtrim(neField.Value)));
        case 'Covariance'
            covTrial = true;
            covList = str2double(strsplit(strtrim(covValueField.Value)));
            changeQ = strcmp(covBG.SelectedObject.Text,'Q');
            changeR = strcmp(covBG.SelectedObject.Text,'R');
            changeP = strcmp(covBG.SelectedObject.Text,'P');
        case 'Measurement Noise'
            noiseTrial = true;
            noiseStdList = str2double(strsplit(strtrim(noiseStdField.Value)));
    end

    %Filter Flags
    useUKF = ukfCheck.Value;
    useEKF = ekfCheck.Value;
    useEnKF = enkfCheck.Value;

    %Case Parameter Assignments
    if useSim && ~useMeas
        nTrials = simTrialField.Value;
        measFreqList = str2num(measFreqField.Value);%#ok<ST2NM>
    elseif ~useSim && useMeas
        nTrialsUKF = ukfTrialField.Value;
        nTrialsEKF = ekfTrialField.Value;
        nTrialsEnKF = enkfTrialField.Value;
    elseif useSim && useMeas
        nTrials = simTrialField.Value;
        nTrialsUKF = ukfTrialField.Value;
        nTrialsEKF = ekfTrialField.Value;
        nTrialsEnKF = nTrials;
    end

    delete(fig);

    %Internal Functions
    function updateCases()
        selectedSource = dataBG.SelectedObject.Text;

        %Enable/Disable Buttons
        if strcmp(selectedSource,'Simulation')
            noiseButton.Enable = true;
        else
            noiseButton.Enable = false;

            if caseBG.SelectedObject == noiseButton
                caseBG.SelectedObject = baseButton;
            end
        end
    
        %Update Base Setting Options
        if strcmp(selectedSource,'Simulation')
            simTrialLabel.Text = 'Simulation Trials:';

            simTrialLabel.Visible = true;
            simTrialField.Visible = true;
        
            ukfTrialLabel.Visible = false;
            ukfTrialField.Visible = false;
        
            ekfTrialLabel.Visible = false;
            ekfTrialField.Visible = false;
        
            enkfTrialLabel.Visible = false;
            enkfTrialField.Visible = false;

            measFreqLabel.Visible = true;
            measFreqField.Visible = true;
            measFreqHelp.Visible = true;
        elseif strcmp(selectedSource,'Measurement')
            simTrialLabel.Visible = false;
            simTrialField.Visible = false;
        
            ukfTrialLabel.Visible = true;
            ukfTrialField.Visible = true;
        
            ekfTrialLabel.Visible = true;
            ekfTrialField.Visible = true;
        
            enkfTrialLabel.Visible = true;
            enkfTrialField.Visible = true;

            measFreqLabel.Visible = false;
            measFreqField.Visible = false;
            measFreqHelp.Visible = false;
        elseif strcmp(selectedSource,'Both')        
            simTrialLabel.Text = 'Sim / EnKF Meas Trials:';
        
            simTrialLabel.Visible = true;
            simTrialField.Visible = true;
        
            ukfTrialLabel.Visible = true;
            ukfTrialField.Visible = true;
        
            ekfTrialLabel.Visible = true;
            ekfTrialField.Visible = true;
        
            enkfTrialLabel.Visible = false;
            enkfTrialField.Visible = false;  

            measFreqLabel.Visible = false;
            measFreqField.Visible = false;
            measFreqHelp.Visible = false;
        end
        updateCase();
    end
    
    function updateCase()
        selectedCase = caseBG.SelectedObject.Text;

        % Reset
        neLabel.Visible = false;
        neField.Visible = false;
        neHelp.Visible = false;

        ukfCheck.Enable = true;
        ekfCheck.Enable = true;
        enkfCheck.Enable = true;

        covValueLabel.Visible = false;
        covValueField.Visible = false;
        covValueHelp.Visible = false;

        covSelectLabel.Visible = false;
        covBG.Visible = false;

        noiseStdLabel.Visible = false;
        noiseStdField.Visible = false;
        noiseStdHelp.Visible = false;

        if ~strcmp(selectedCase, 'Ensemble Size') && ...
                ~strcmp(selectedSource, 'Simulation')
        
            ukfTrialLabel.Visible = true;
            ukfTrialField.Visible = true;
        
            ekfTrialLabel.Visible = true;
            ekfTrialField.Visible = true;
        end

        switch selectedCase
            case 'Base'

            case 'Ensemble Size'
                ukfCheck.Value = false;
                ekfCheck.Value = false;
                enkfCheck.Value = true;
    
                ukfCheck.Enable = false;
                ekfCheck.Enable = false;
                enkfCheck.Enable = false;
    
                neLabel.Visible = true;
                neField.Visible = true;
                neHelp.Visible = true;

                ukfTrialLabel.Visible = false;
                ukfTrialField.Visible = false;
                
                ekfTrialLabel.Visible = false;
                ekfTrialField.Visible = false;
            case 'Covariance'
                covValueLabel.Visible = true;
                covValueField.Visible = true;
                covValueHelp.Visible = true;

                covSelectLabel.Visible = true;
                covBG.Visible = true;
            case 'Measurement Noise'
                noiseStdLabel.Visible = true;
                noiseStdField.Visible = true;
                noiseStdHelp.Visible = true;
        end
    end

    function validateSetup()
        %At least one filter check
        if ~ukfCheck.Value && ~ekfCheck.Value && ~enkfCheck.Value
            uialert(fig,...
                'Select at least one filter.',...
                'No Filter Selected');
            return
        end

        %Validate measurement rate
        if strcmp(dataBG.SelectedObject.Text,'Simulation') && ...
                any(strcmp(caseBG.SelectedObject.Text,{'Base','Ensemble Size'}))
            
            measFreqTest = str2double(strsplit(strtrim(measFreqField.Value)));

            if isempty(measFreqTest) || any(isnan(measFreqTest)) || ...
                    any(~isfinite(measFreqTest)) || any(measFreqTest <= 0)

                uialert(fig,...
                    'Measurement rates must be positive numbers separated by spaces.',...
                    'Invalid Measurement Rate');
                return
            end
        end

        % Validate ensemble sizes
        if strcmp(caseBG.SelectedObject.Text,'Ensemble Size')    
            neTest = str2double(strsplit(strtrim(neField.Value)));
        
            if isempty(neTest) || any(isnan(neTest)) || ...
                    any(~isfinite(neTest)) || any(neTest <= 0) || ...
                    any(mod(neTest,1) ~= 0)
        
                uialert(fig,...
                    'Ensemble sizes must be positive integers separated by spaces.',...
                    'Invalid Ensemble Size');
                return
            end
        end

        % Validate covariance multipliers
        if strcmp(caseBG.SelectedObject.Text,'Covariance')        
            covTest = str2double(strsplit(strtrim(covValueField.Value)));
        
            if isempty(covTest) || any(isnan(covTest)) || ...
                    any(~isfinite(covTest)) || any(covTest <= 0)
        
                uialert(fig,...
                    'Covariance multipliers must be positive numbers separated by spaces.',...
                    'Invalid Covariance Multipliers');
                return
            end
        end

        % Validate measurement noise standard deviations
        if strcmp(caseBG.SelectedObject.Text,'Measurement Noise')
        
            noiseStdTest = str2double(strsplit(strtrim(noiseStdField.Value)));
        
            if isempty(noiseStdTest) || any(isnan(noiseStdTest)) || ...
                    any(~isfinite(noiseStdTest)) || any(noiseStdTest < 0)
        
                uialert(fig,...
                    'Noise standard deviations must be nonnegative numbers separated by spaces.',...
                    'Invalid Noise Standard Deviation');
                return
            end
        end
        uiresume(fig);
    end

    function keyPress(event)
        if strcmp(event.Key,'return') || strcmp(event.Key,'enter')
            validateSetup();
        end
    end
end