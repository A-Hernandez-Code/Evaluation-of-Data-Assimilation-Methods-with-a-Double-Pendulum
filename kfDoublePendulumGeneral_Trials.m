clearvars
%clc

%%ADDITIONS
%Runtime should track, individual DA steps
%Same plots for 3 measurement cases, different starting condition

%Data Saving and Cases
saveData = true;
makeVideo = false;
timeTrial = false;

%Run Setup
[useSim,useMeas,...
    base,ensTrial,covTrial,noiseTrial,...
    useUKF,useEKF,useEnKF,...
    nTrials,nTrialsUKF,nTrialsEKF,nTrialsEnKF,...
    measFreqList,neList,covList,noiseStdList,...
    changeQ,changeR,changeP] = setupRun;

%Setting up filterNames
filterNames = {};
if useUKF
    filterNames{end+1} = 'UKF';
end
if useEKF
    filterNames{end+1} = 'EKF';
end
if useEnKF
    filterNames{end+1} = 'EnKF';
end

%Checks
if covTrial && sum([changeQ,changeR,changeP]) ~=1
    error('Set only one Change parameter to True');
end

if sum([covTrial,ensTrial,noiseTrial]) > 1
    error('Set only one Trial Type');
end

if (useMeas || ~useSim) && noiseTrial
    error('Selected Trial Type is only for simulated data');
end


%Measurement Data Selection
%Measured
fileDate = "02-Aug-2026 15_58_03";

%File Validation
if ~useSim && ~useMeas
    error('Neither simulated nor measured data is enabled.') %#ok<*UNRCH>
end

if useMeas
    dataFolder = fullfile('DataStorage',fileDate);
    filePB = "dataPB_" + fileDate + ".mat";
    fileSB = "dataSB_" + fileDate + ".mat";

    if ~isfile(fullfile(dataFolder,filePB))
        error("File not found: %s", filePB);
    end

    if ~isfile(fullfile(dataFolder,fileSB))
        error("File not found: %s", fileSB);
    end
end

%Simulation Setup
setup = doublePendulumSetupMatrix;
dt = setup.dt;
Tstop = setup.Tstop;
t = setup.t;
N = setup.N;
x0 = setup.x0;
xTrue0 = setup.xTrue0;
stateFcn = setup.stateFcn;
measFcn = setup.measFcn;

m1 = setup.m1;
m2 = setup.m2;
l1 = setup.l1;
l2 = setup.l2;

%Measurement Frequency to modN
modNList = round(1 ./ (measFreqList .* dt));

%Kalman Filter Parameters
estStates = numel(x0);
measStates = numel(measFcn(x0));

%Different for simulated vs measured
if useSim
    qSim = 0;
    rSim = 1e-3;
    pSim = 0.5;

    QSim = qSim * eye(estStates);
    RSim = rSim * eye(measStates);
    P0Sim = pSim * eye(estStates); 
end
if useMeas
    qMeas = 6e-6;
    rMeas = diag([1.341828e-5, 6.023725e-5]);
    pMeas = 0.5;

    QMeas = qMeas * eye(estStates);
    RMeas = rMeas;
    P0Meas = pMeas * eye(estStates); 
end

if changeQ
    covType = 'Q';
elseif changeR
    covType = 'R';
elseif changeP
    covType = 'P';
end

if ~covTrial
    covList = 1;
end

if ~noiseTrial
    noiseStdList = 1e-3;
end

if ~ensTrial
    neList = 50;
end

Ne = neList;

%Run Information
numFilters = numel(filterNames);

if ensTrial
    numRuns = (useSim * numel(neList) * nTrials) + ...
        (useMeas * numel(neList) * nTrialsEnKF);
elseif covTrial
    numSimRuns = useSim * numel(covList) * nTrials * numFilters;
    numMeasRuns = useMeas * numel(covList) * (useUKF*nTrialsUKF + ...
                                              useEKF*nTrialsEKF + ...
                                              useEnKF*nTrialsEnKF);
    numRuns = numSimRuns + numMeasRuns;
elseif noiseTrial
    numRuns = useSim * numel(noiseStdList) * nTrials * numFilters;
else
    if useMeas
        numSimCases = 1;
    else
        numSimCases = numel(modNList);
    end

    numSimRuns = useSim * numSimCases * nTrials * numFilters;
    numMeasRuns = useMeas * (useUKF*nTrialsUKF + ...
                             useEKF*nTrialsEKF + ...
                             useEnKF*nTrialsEnKF);
    numRuns = numSimRuns + numMeasRuns;
end

runCount = 0;

%Measurement Data Setup
if useMeas
    Tstop = 20;
    t = 0:dt:Tstop;
    N = length(t);

    load(fullfile(dataFolder,filePB));
    load(fullfile(dataFolder,fileSB));

    Nmeas = length(dataPB);
    
    yInd = round(linspace(2,N,Nmeas));
    
    measCheck = false(1,N);
    measCheck(yInd) = true;

    if useSim
        simCheck = measCheck;
    end
    
    yMeas = zeros(2,N);
    yMeas(1,yInd) = dataPB.';
    yMeas(2,yInd) = dataSB.';
end

if useSim
    %Generate True Data
    xTrue = zeros(estStates,N);
    xTrue(:,1) = xTrue0;

    for k = 1:N-1
        xTrue(:,k+1) = stateFcn(xTrue(:,k),dt);
    end
end

%Filter Parameters
if useSim
    kfParamsSim.x0 = x0;
    kfParamsSim.Q = QSim;
    kfParamsSim.R = RSim;
    kfParamsSim.P0 = P0Sim;
    kfParamsSim.Ne = Ne;
end

if useMeas
    kfParamsMeas.x0 = x0;
    kfParamsMeas.Q = QMeas;
    kfParamsMeas.R = RMeas;
    kfParamsMeas.P0 = P0Meas;
    kfParamsMeas.Ne = Ne;
end

%Filter Functions
kfFcn.state = stateFcn;
kfFcn.meas = measFcn;

%Run Counter
runInfo.runCount = runCount;
runInfo.numRuns = numRuns;

%Trial Data
trialData.dt = dt;

%Kalman Filter
%% Ensemble Size Case
if ensTrial 
    filterName = 'EnKF';
    if useSim
        kfParams = kfParamsSim;
        for trial = 1:nTrials
            trialName = sprintf('trial_%d',trial);
            
            simMeas = xTrue(1:2,:) + mvnrnd(zeros(N,measStates),RSim)';
            
            for n = 1:numel(neList)
                Ne = neList(n);
                neName = sprintf('ne_%d',Ne);
    
                kfParams.Ne = Ne;
    
                for m = 1:numel(modNList)
                    modN = modNList(m);
                    modName = sprintf('modN_%d',modN);
    
                    simCheck = false(1,N);
                    simCheck(modN:modN:N) = true;
    
                    trialData.xTrue = xTrue;
                    trialData.yMeas = simMeas;
                    trialData.measCheck = simCheck;
    
                    if n == 1
                        simData.(modName).(trialName).yMeas = single(simMeas(:,simCheck));
                    end
    
                    runCount = runCount + 1;
                    runInfo.runCount = runCount;
    
                    [results.Sim.(filterName).(neName).(modName).(trialName),...
                         runtime.Sim.(filterName).(neName).(modName).times(trial)] = ...
                         runFilter(filterName,kfParams,kfFcn,trialData,runInfo);
                end
            end
        end
    end
    if useMeas
        kfParams = kfParamsMeas;   
        for trial = 1:nTrialsEnKF
            trialName = sprintf('trial_%d',trial);
    
            for n = 1:numel(neList)
                Ne = neList(n);
                neName = sprintf('ne_%d',Ne);
    
                kfParams.Ne = Ne;
    
                trialData.xTrue = [];
                trialData.yMeas = yMeas;
                trialData.measCheck = measCheck;
    
                runCount = runCount + 1;
                runInfo.runCount = runCount;
    
                [results.Meas.(filterName).(neName).(trialName), ...
                 runtime.Meas.(filterName).(neName).times(trial)] = ...
                    runFilter(filterName,kfParams,kfFcn,trialData,runInfo);
            end
        end
    end
%% Noise Covariance Case
elseif covTrial
    if useMeas
        kfParams = kfParamsMeas;
        for c = 1:numel(covList)
            QCov = QMeas;
            RCov = RMeas;
            P0Cov = P0Meas;

            if changeQ
                QCov = covList(c) * QMeas;
                covName = sprintf('Q_%d',c);
            elseif changeR
                RCov = covList(c) * RMeas;
                covName = sprintf('R_%d',c);
            elseif changeP
                P0Cov = covList(c) * P0Meas;
                covName = sprintf('P_%d',c);
            end
            
            trialData.xTrue = [];
            trialData.yMeas = yMeas;
            trialData.measCheck = measCheck;

            kfParams.Q = QCov;
            kfParams.R = RCov;
            kfParams.P0 = P0Cov;

            for f = 1:numel(filterNames)
                filterName = filterNames{f};
    
                switch filterName
                    case 'UKF'
                        nTrialsMeas = nTrialsUKF;
                    case 'EKF'
                        nTrialsMeas = nTrialsEKF;
                    case 'EnKF'
                        nTrialsMeas = nTrialsEnKF;
                end
                
                for trial = 1:nTrialsMeas
                    trialName = sprintf('trial_%d',trial);
                    runCount = runCount + 1;
                    runInfo.runCount = runCount;

                    [results.Meas.(filterName).(covName).(trialName),...
                        runtime.Meas.(filterName).(covName).times(trial)] = ...
                        runFilter(filterName,kfParams,kfFcn,trialData,runInfo);
                end
            end
        end
    end
    if useSim
        modN = modNList;
        if ~useMeas
            simCheck = false(1,N);
            simCheck(modN:modN:N) = true;
        end

        kfParams = kfParamsSim;

        for trial = 1:nTrials
                trialName = sprintf('trial_%d',trial);
                simMeas = xTrue(1:2,:) + mvnrnd(zeros(N,measStates),RSim)';

                simData.(trialName).yMeas = single(simMeas(:,simCheck));

            for c = 1:numel(covList)
                QCov = QSim;
                RCov = RSim;
                P0Cov = P0Sim;
    
                if changeQ
                    QCov = covList(c) * QSim;
                    covName = sprintf('Q_%d',c);
                elseif changeR
                    RCov = covList(c) * RSim;
                    covName = sprintf('R_%d',c);
                elseif changeP
                    P0Cov = covList(c) * P0Sim;
                    covName = sprintf('P_%d',c);
                end

                trialData.xTrue = xTrue;
                trialData.yMeas = simMeas;
                trialData.measCheck = simCheck;

                kfParams.Q = QCov;
                kfParams.R = RCov;
                kfParams.P0 = P0Cov;

                for f = 1:numel(filterNames)
                    filterName = filterNames{f};
                    runCount = runCount + 1;
                    runInfo.runCount = runCount;

                    [results.Sim.(filterName).(covName).(trialName),...
                        runtime.Sim.(filterName).(covName).times(trial)] = ...
                        runFilter(filterName,kfParams,kfFcn,trialData,runInfo);
                end
            end
        end
    end
%% Simulated Measurement Noise Case
elseif noiseTrial
    modN = modNList;
    simCheck = false(1,N);
    simCheck(modN:modN:N) = true;

    kfParams = kfParamsSim;

    for trial = 1:nTrials
        trialName = sprintf('trial_%d',trial);

        for n = 1:numel(noiseStdList)
            noiseStd = noiseStdList(n);
            noiseName = sprintf('noise_%d',n);

            noiseMeas = noiseStd^2 * eye(measStates);

            simMeas = xTrue(1:2,:) + mvnrnd(zeros(N,measStates),noiseMeas)';

            simData.(noiseName).(trialName).yMeas = single(simMeas(:,simCheck));
            simData.(noiseName).noiseStd = noiseStd;

            trialData.xTrue = xTrue;
            trialData.yMeas = simMeas;
            trialData.measCheck = simCheck;
            kfParams.R = noiseMeas;

            for f = 1:numel(filterNames)
                filterName = filterNames{f};
                runCount = runCount + 1;
                runInfo.runCount = runCount;

                [results.Sim.(filterName).(noiseName).(trialName),...
                 runTime.(filterName).(noiseName).times(trial)] = ...
                    runFilter(filterName,kfParams,kfFcn,trialData,runInfo);            
            end
        end
    end
%% Base Case (or Simulated ModNList)
else
    if useMeas
        trialData.xTrue = [];
        trialData.yMeas = yMeas;
        trialData.measCheck = measCheck;

        kfParams = kfParamsMeas;

        for f = 1:numel(filterNames)
            filterName = filterNames{f};

            switch filterName
                case 'UKF'
                    nTrialsMeas = nTrialsUKF;
                case 'EKF'
                    nTrialsMeas = nTrialsEKF;
                case 'EnKF'
                    nTrialsMeas = nTrialsEnKF;
            end
            
            for trial = 1:nTrialsMeas
                trialName = sprintf('trial_%d',trial);
                runCount = runCount + 1;
                runInfo.runCount = runCount;

                [results.Meas.(filterName).(trialName),...
                     runtime.Meas.(filterName).times(trial)] = ...
                     runFilter(filterName,kfParams,kfFcn,trialData,runInfo);
            end
        end
    end
    if useSim
        if useMeas
            modLoop = 1;
        else
            modLoop = 1:numel(modNList);
        end

        kfParams = kfParamsSim;

        for trial = 1:nTrials
            trialName = sprintf('trial_%d',trial);

            simMeas = xTrue(1:2,:) + mvnrnd(zeros(N,measStates),RSim)';

            for m = modLoop
                if useMeas
                    modName = 'matchedMeas';
                else
                    modN = modNList(m);
                    modName = sprintf('modN_%d',modN);

                    simCheck = false(1,N);
                    simCheck(modN:modN:N) = true;
                end

                simData.(modName).(trialName).yMeas = single(simMeas(:,simCheck));

                trialData.xTrue = xTrue;
                trialData.yMeas = simMeas;
                trialData.measCheck = simCheck;

                for f = 1:numel(filterNames)
                    filterName = filterNames{f};
                    runCount = runCount + 1;
                    runInfo.runCount = runCount;
                    
                    [results.Sim.(filterName).(modName).(trialName),...
                     runtime.Sim.(filterName).(modName).times(trial)] = ...
                     runFilter(filterName,kfParams,kfFcn,trialData,runInfo);
                end
            end
        end
    end
end

%Data Saving
if saveData    
    saveTime = string(datetime('now','Format','dd-MMM-yyyy_HH_mm_ss'));    
    saveFolder = "Results/Current";

    dataTypes = strings(0);

    metadata.timeTrial = timeTrial;
    metadata.ensTrial = ensTrial;
    metadata.covTrial = covTrial;
    metadata.noiseTrial = noiseTrial;
    
    metadata.filterNames = filterNames;
    
    metadata.useSim = useSim;
    metadata.useMeas = useMeas;

    if covTrial
        metadata.covType = covType;
        metadata.covList = covList;
    end

    if noiseTrial
        metadata.noiseStdList = noiseStdList;
    end

    metadata.dt = dt;
    metadata.Tstop = Tstop;
    metadata.N = N;

    if useSim
        metadata.modNList = modNList;
        metadata.nTrials = nTrials;

        simData.xTrue = single(xTrue);

        dataTypes(end+1) = "Sim";
    end

    if useMeas
        metadata.nTrialsUKF = nTrialsUKF;
        metadata.nTrialsEKF = nTrialsEKF;
        metadata.nTrialsEnKF = nTrialsEnKF;

        measData.yMeas = yMeas;
        measData.measCheck = measCheck;
        measData.fileDate = fileDate;
        metadata.fileDate = fileDate;

        dataTypes(end+1) = "Meas";
    end

    metadata.neList = neList;

    metadata.l1 = l1;
    metadata.l2 = l2;
    metadata.m1 = m1;
    metadata.m2 = m2;
    
    metadata.estStates = estStates;
    metadata.measStates = measStates;
    
    metadata.saveTime = saveTime;

    if ~timeTrial
        resultsTemp = results;
    end

    runtimeTemp = runtime;

    %Save Setup
    for dataType = dataTypes
        if timeTrial
            saveName = "DAtiming_" + dataType + "_" + saveTime + ".mat";
        elseif ensTrial
            saveName = "DAens_" + dataType + "_" + saveTime + ".mat";
        elseif covTrial
            saveName = "DAcov_" + dataType + "_" + saveTime + ".mat";
        elseif noiseTrial
            saveName = "DAnoise_" + dataType + "_" + saveTime + ".mat";
        else
            saveName = "DAresults_" + dataType + "_" + saveTime + ".mat";
        end

        savePath = fullfile(saveFolder,saveName);

        metadata.dataType = dataType;

        saveVars = {'runtime','metadata'};

        if dataType == "Sim"
            runtime = struct('Sim',runtimeTemp.Sim);
            saveVars{end+1} = 'simData';
        elseif dataType == "Meas"
            runtime = struct('Meas',runtimeTemp.Meas);
            saveVars{end+1} = 'measData';
        end

        if ~timeTrial
            if dataType == "Sim"
                results = struct('Sim',resultsTemp.Sim);
                saveVars{end+1} = 'simData';
            elseif dataType == "Meas"
                results = struct('Meas',resultsTemp.Meas);
                saveVars{end+1} = 'measData';
            end

            saveVars{end+1} = 'results';
        end
    
        save(savePath,saveVars{:},'-v7.3');
    end

    if ~timeTrial
        results = resultsTemp;
    end

    runtime = runtimeTemp;
end

%% Local Functions
%Kalman Filter Recursion
function[x,P,NIS,NEES,innov,updateIdx] = kfRecursion(kfData,xTrue,yMeas,dt,measCheck,runCount,numRuns)
    kfType = getKFType(kfData);
    N = size(yMeas,2);
    measStates = size(yMeas,1);
    [x0current,~] = getKFState(kfData,kfType);
    estStates = length(x0current);

    numUpdates = nnz(measCheck);
    updateIdx = find(measCheck);

    %Data Collection
    x = NaN(estStates,N);
    %P = NaN(estStates,estStates,N); state covariance at all timesteps
    P = NaN(estStates,numUpdates); %state covariance at all updates
    
    innov = NaN(measStates,numUpdates);
    S = NaN(measStates,measStates); %#ok<*NASGU>
    NIS = NaN(1,numUpdates);
    NEES = NaN(1,numUpdates);

    [x(:,1),Pcurrent] = getKFState(kfData,kfType);

    j = 0;
    for k = 2:N
        kfData = kfPredict(kfData,kfType,dt);

        if measCheck(k)
            j = j + 1;

            fprintf('Run %d of %d - Iteration %d of %d\n',runCount,numRuns,k,N);

            [kfData,innov(:,j),S] = kfUpdate(kfData,kfType,yMeas(:,k));
            
            NIS(j) = innov(:,j)' * (S \ innov(:,j));

            [x(:,k),Pcurrent] = getKFState(kfData,kfType);
            P(:,j) = diag(Pcurrent);

            if ~isempty(xTrue)
                error = x(:,k) - xTrue(:,k);
                NEES(j) = error' * (Pcurrent \ error);
            end
        else
            [x(:,k),~] = getKFState(kfData,kfType);
        end

        if any(isnan(x(:,k)))
            fprintf('Loop stopped at iteration %d of run %d: NaN detected\n',k,runCount);
            break; % Exits the loop immediately
        end

        if measCheck(k) && any(isnan(Pcurrent(:)))
            fprintf('Loop stopped at iteration %d of run %d: NaN detected\n',k,runCount);
            break; % Exits the loop immediately
        end
    end
    x = single(x);
    P = single(P);
end

%Kalman Filter Setup
function ukf = setupUKF(x0,Q,R,P0,stateFcn,measFcn)
    ukf = unscentedKalmanFilter(stateFcn,measFcn,x0);

    ukf.ProcessNoise = Q;
    ukf.MeasurementNoise = R;
    ukf.StateCovariance = P0;
end

function ekf = setupEKF(x0,Q,R,P0,stateFcn,measFcn)
    ekf = extendedKalmanFilter(stateFcn,measFcn,x0);
    
    ekf.ProcessNoise = Q;
    ekf.MeasurementNoise = R;
    ekf.StateCovariance = P0;
end

function enkf = setupEnKF(x0,Q,R,P0,stateFcn,measFcn,Ne)   
    enkf.type = 'EnKF';
    enkf.Xensem = mvnrnd(x0',P0,Ne)';

    enkf.StateTransitionFcn = stateFcn;
    enkf.MeasurementFcn = measFcn;

    enkf.ProcessNoise = Q;
    enkf.MeasurementNoise = R;
end

function kfData = initializeKF(filterName,x0,Q,R,P0,stateFcn,measFcn,Ne)
    switch filterName
        case 'UKF'
            kfData = setupUKF(x0,Q,R,P0,stateFcn,measFcn);
        case 'EKF'
            kfData = setupEKF(x0,Q,R,P0,stateFcn,measFcn);
        case 'EnKF'
            kfData = setupEnKF(x0,Q,R,P0,stateFcn,measFcn,Ne);
        otherwise
            error('Unknown Kalman filter: %s',filterName);
    end
end

%Kalman Filter Information
function [xCurrent, PCurrent] = getKFState(kfData,kfType)
    if strcmpi(kfType,'EnKF')
        xCurrent = mean(kfData.Xensem,2);
        PCurrent = cov(kfData.Xensem');
    elseif strcmpi(kfType,'BuiltIn')
        xCurrent = kfData.State;
        PCurrent = kfData.StateCovariance;
    end
end

function kfType = getKFType(kfData)
    if isstruct(kfData) && isfield(kfData,'type')
        kfType = kfData.type;
    else
        kfType = 'BuiltIn';
    end
end

%Kalman Filter Predict/Update
function kfData = kfPredict(kfData,kfType,dt)
    if strcmpi(kfType,'EnKF')
        kfData = enkfPredict(kfData,dt);
    elseif strcmpi(kfType,'BuiltIn')
        predict(kfData,dt);
    end
end

function [kfData,innov,S] = kfUpdate(kfData,kfType,yMeas)
    if strcmpi(kfType,'EnKF')
        [kfData,innov,S] = enkfUpdate(kfData,yMeas);
    elseif strcmpi(kfType,'BuiltIn')
        [innov,S] = residual(kfData,yMeas);
        correct(kfData,yMeas);
    end
end

function enkf = enkfPredict(enkf,dt)
    [estStates,Ne] = size(enkf.Xensem);
    
    %Propagate each ensemble member
    %TESTING
    % for i = 1:Ne
    %     enkf.Xensem(:,i) = enkf.StateTransitionFcn(enkf.Xensem(:,i),dt);
    % end
    enkf.Xensem = enkf.StateTransitionFcn(enkf.Xensem,dt);

    %Add process noise
    W = mvnrnd(zeros(estStates,1),enkf.ProcessNoise,Ne)';
    enkf.Xensem = enkf.Xensem + W;
end

function [enkf,innov,S] = enkfUpdate(enkf,yMeas)
    Ne = size(enkf.Xensem,2);
    measStates = length(yMeas);

    %Predicted measurements for each ensemble member
    Yensem = enkf.MeasurementFcn(enkf.Xensem);

    %Ensemble means
    xMean = mean(enkf.Xensem,2);
    yMean = mean(Yensem,2);

    %Deviations from the means
    Xdev = enkf.Xensem - xMean;
    Ydev = Yensem - yMean;

    %Covariances
    Pxy = (Xdev * Ydev') / (Ne - 1);
    S = (Ydev * Ydev') / (Ne - 1) + enkf.MeasurementNoise;

    %Kalman gain
    K = Pxy / S;

    %Perturbed measurements for each ensemble member
    V = mvnrnd(zeros(measStates,1),enkf.MeasurementNoise,Ne)';

    YmeasPert = yMeas + V;

    %Update ensemble
    enkf.Xensem = enkf.Xensem + K * (YmeasPert - Yensem);

    %Innovation
    innov = yMeas - yMean;
end

%General Filter Run
function [resultData,runTime] = runFilter(filterName,kfParams,kfFcn,trialData,runInfo)
    kfData = initializeKF(filterName,...
                        kfParams.x0,...
                        kfParams.Q,...
                        kfParams.R,...
                        kfParams.P0,...
                        kfFcn.state,...
                        kfFcn.meas,...
                        kfParams.Ne);
    tic;

    [resultData.x,...
     resultData.P,...
     resultData.NIS,...
     resultData.NEES,...
     resultData.innov,...
     resultData.updateIdx] = kfRecursion(kfData,...
                                         trialData.xTrue,...
                                         trialData.yMeas,...
                                         trialData.dt,...
                                         trialData.measCheck,...
                                         runInfo.runCount,...
                                         runInfo.numRuns);
    runTime = toc;

    if isempty(trialData.xTrue)
        resultData = rmfield(resultData,'NEES');
    end
end