clearvars
close all
clc

%Analysis Settings
saveFigures = false;

%Load Data To Analyze
[fileName,filePath] = uigetfile(fullfile('Results','Current','.mat'),...
                                      'Select Results File');

if isequal(fileName,0)
    error('No results file selected')
end

load(fullfile(filePath,fileName));

%Determine Settings And Case
useSim = metadata.useSim;
useMeas = metadata.useMeas;

filterNames = metadata.filterNames;

dt = metadata.dt;
Tstop = metadata.Tstop;
N = metadata.N;
t = 0:dt:Tstop;

neList = metadata.neList;

if useSim
    modNList = metadata.modNList;
    nTrials = metadata.nTrials;
end

if useMeas
    nTrialsUKF = metadata.nTrialsUKF;
    nTrialsEKF = metadata.nTrialsEKF;
    nTrialsEnKF = metadata.nTrialsEnKF;

    measCheck = measData.measCheck;
end

if metadata.ensTrial
    caseType = 'Ensemble';
elseif metadata.covTrial
    caseType = 'Covariance';
    covList = metadata.covList;
    covType = metadata.covType;
elseif metadata.noiseTrial
    caseType = 'Noise';
    noiseStdList = metadata.noiseStdList;
else
    caseType = 'Base';
end

estStates = metadata.estStates;
measStates = metadata.measStates;

%Analysis Based On Case
switch caseType
    case 'Base'
        %Metric Calculation
        if useSim
            for f = 1:numel(filterNames)
                filterName = filterNames{f};

                for m = 1:numel(modNList)
                    modN = modNList(m);
                    modNName = sprintf('modN_%d',modN);

                    RMSEtrials = NaN(estStates,nTrials);
                    RMSItrials = NaN(measStates,nTrials);
                    NIStrials = NaN(1,nTrials);
                    NEEStrials = NaN(1,nTrials);

                    for trial = 1:nTrials
                        trialName = sprintf('trial_%d',trial);
                        resultData = results.Sim.(filterName).(modNName).(trialName);
                        metrics = calcMetrics(resultData,simData.xTrue);

                        RMSEtrials(:,trial) = metrics.RMSE;
                        RMSItrials(:,trial) = metrics.RMSI;
                        NIStrials(trial) = metrics.meanNIS;
                        NEEStrials(trial) = metrics.meanNEES;
                    end
                    
                    summary.Sim.(filterName).(modNName) = ...
                        summarizeMetrics(RMSEtrials,RMSItrials,NIStrials,NEEStrials);
                end
            end
        end
        if useMeas
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

                RMSItrials = NaN(measStates,nTrialsMeas);
                NIStrials = NaN(1,nTrialsMeas);

                for trial = 1:nTrialsMeas
                    trialName = sprintf('trial_%d',trial);
                    resultData = results.Meas.(filterName).(trialName);
                    metrics = calcMetrics(resultData,[]);

                    RMSItrials(:,trial) = metrics.RMSI;
                    NIStrials(trial) = metrics.meanNIS;
                end

                summary.Meas.(filterName) = ...
                        summarizeMetrics([],RMSItrials,NIStrials,[]);
            end
        end

        %Plotting Results
        if useSim
            figsBefore = findall(groot,'Type','figure');

            measHz = 1 ./ (modNList * dt);
            [measHz,sortIdx] = sort(measHz);
            modNList = modNList(sortIdx);

            [RMSEmean,RMSEstd] = getSimMetric(summary,filterNames,modNList,'RMSE');
            plotRMSE(measHz,RMSEmean,RMSEstd,filterNames,'Measurement Frequency (Hz)');

            [RMSImean,RMSIstd] = getSimMetric(summary,filterNames,modNList,'RMSI');
            plotRMSI(measHz,RMSImean,RMSIstd,filterNames,'Sim','Measurement Frequency (Hz)');

            [NISmean,NISstd] = getSimMetric(summary,filterNames,modNList,'NIS');
            plotNIS(measHz,NISmean,NISstd,filterNames,'Sim','Measurement Frequency (Hz)');

            [NEESmean,NEESstd] = getSimMetric(summary,filterNames,modNList,'NEES');
            plotNEES(measHz,NEESmean,NEESstd,filterNames,'Measurement Frequency (Hz)',false);

            [runtimeMean,runtimeStd] = getSimRuntime(runtime,filterNames,modNList);
            plotRuntime(measHz,runtimeMean,runtimeStd,filterNames,'Sim','Measurement Frequency (Hz)');
            
            simFigures = setdiff(findall(groot,'Type','figure'),figsBefore);
        end

        if useMeas
            figsBefore = findall(groot,'Type','figure');

            [RMSImean,RMSIstd] = getMeasMetric(summary,filterNames,'RMSI');
            plotRMSI([],RMSImean,RMSIstd,filterNames,'Meas','');

            [NISmean,NISstd] = getMeasMetric(summary,filterNames,'NIS');
            plotNIS([],NISmean,NISstd,filterNames,'Meas','');

            [runtimeMean,runtimeStd] = getMeasRuntime(runtime,filterNames);
            plotRuntime([],runtimeMean,runtimeStd,filterNames,'Meas','');

            measFigures = setdiff(findall(groot,'Type','figure'),figsBefore);
        end
    case 'Ensemble'
        %Metric Calculation
        if useSim
            modN = modNList(1);
            modNName = sprintf('modN_%d',modN);
    
            for n = 1:numel(neList)
                neName = sprintf('ne_%d',neList(n));
    
                RMSEtrials = NaN(estStates, nTrials);
                RMSItrials = NaN(measStates, nTrials);
                NIStrials  = NaN(1, nTrials);
                NEEStrials = NaN(1, nTrials); 
    
                for trial = 1:nTrials
                    trialName = sprintf('trial_%d',trial);
                    resultData = results.Sim.EnKF.(neName).(modNName).(trialName);
                    metrics = calcMetrics(resultData,simData.xTrue);
    
                    RMSEtrials(:,trial) = metrics.RMSE;
                    RMSItrials(:,trial) = metrics.RMSI;
                    NIStrials(trial) = metrics.meanNIS;
                    NEEStrials(trial) = metrics.meanNEES;
                end
    
                summary.Sim.EnKF.(neName) = summarizeMetrics(...
                    RMSEtrials,RMSItrials,NIStrials,NEEStrials);
            end
        end

        if useMeas
            for n = 1:numel(neList)
                Ne = neList(n);
                neName = sprintf('ne_%d',Ne);
        
                RMSItrials = NaN(measStates,nTrialsEnKF);
                NIStrials = NaN(1,nTrialsEnKF);
        
                for trial = 1:nTrialsEnKF
                    trialName = sprintf('trial_%d',trial);
        
                    resultData = results.Meas.EnKF.(neName).(trialName);
                    metrics = calcMetrics(resultData,[]);
        
                    RMSItrials(:,trial) = metrics.RMSI;
                    NIStrials(trial) = metrics.meanNIS;
                end
        
                summary.Meas.EnKF.(neName) = summarizeMetrics(...
                    [],RMSItrials,NIStrials,[]);
            end
        end

        %Plotting Results
        xLabel = 'Ensemble Size';
        if useSim
            figsBefore = findall(groot,'Type','figure');
    
            [RMSEmean,RMSEstd] = getEnsMetric(summary.Sim,neList,'RMSE');
            plotRMSE(neList,RMSEmean,RMSEstd,filterNames,xLabel);
    
            [RMSImean,RMSIstd] = getEnsMetric(summary.Sim,neList,'RMSI');
            plotRMSI(neList,RMSImean,RMSIstd,filterNames,'Sim',xLabel);
    
            [NISmean,NISstd] = getEnsMetric(summary.Sim,neList,'NIS');
            plotNIS(neList,NISmean,NISstd,filterNames,'Sim',xLabel);
    
            [NEESmean,NEESstd] = getEnsMetric(summary.Sim,neList,'NEES');
            plotNEES(neList,NEESmean,NEESstd,filterNames,xLabel,true);
    
            [runtimeMean,runtimeStd] = getEnsRuntime(runtime,neList,modNList(1));
            plotRuntime(neList,runtimeMean,runtimeStd,filterNames,'Sim',xLabel);
    
            simFigures = setdiff(findall(groot,'Type','figure'),figsBefore);
        end

        if useMeas
            figsBefore = findall(groot,'Type','figure');

            [RMSImean,RMSIstd] = getEnsMetric(summary.Meas,neList,'RMSI');
            plotRMSI(neList,RMSImean,RMSIstd,filterNames,'Sim',xLabel);
            %set(gca,'YScale','log');

            [NISmean,NISstd] = getEnsMetric(summary.Meas,neList,'NIS');
            plotNIS(neList,NISmean,NISstd,filterNames,'Sim',xLabel);
            %set(gca,'YScale','log');

            [runtimeMean,runtimeStd] = getMeasEnsRuntime(runtime,neList);
            plotRuntime(neList,runtimeMean,runtimeStd,filterNames,'Sim',xLabel);
    
            measFigures = setdiff(findall(groot,'Type','figure'),figsBefore);
        end
    case 'Covariance'
        %Metric Calculation
        if useSim            
            for f = 1:numel(filterNames)
                filterName = filterNames{f};

                for c = 1:numel(covList)
                    covName = sprintf('%s_%d',covType,c);

                    RMSEtrials = NaN(estStates, nTrials);
                    RMSItrials = NaN(measStates, nTrials);
                    NIStrials  = NaN(1, nTrials);
                    NEEStrials = NaN(1, nTrials);

                    for trial = 1:nTrials
                        trialName = sprintf('trial_%d',trial);
                        resultData = results.Sim.(filterName).(covName).(trialName);
                        metrics = calcMetrics(resultData,simData.xTrue);

                        RMSEtrials(:,trial) = metrics.RMSE;
                        RMSItrials(:,trial) = metrics.RMSI;
                        NIStrials(trial) = metrics.meanNIS;
                        NEEStrials(trial) = metrics.meanNEES;
                    end

                    summary.Sim.(filterName).(covName) = summarizeMetrics(...
                    RMSEtrials,RMSItrials,NIStrials,NEEStrials);
                end
            end
        end

        if useMeas
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
        
                for c = 1:numel(covList)
                    covName = sprintf('%s_%d',covType,c);
        
                    RMSItrials = NaN(measStates, nTrialsMeas);
                    NIStrials  = NaN(1, nTrialsMeas);
        
                    for trial = 1:nTrialsMeas
                        trialName = sprintf('trial_%d', trial);
                        resultData = results.Meas.(filterName).(covName).(trialName);
                        metrics = calcMetrics(resultData,[]);
        
                        RMSItrials(:,trial) = metrics.RMSI;
                        NIStrials(trial) = metrics.meanNIS;
                    end
        
                    summary.Meas.(filterName).(covName) = ...
                        summarizeMetrics([],RMSItrials,NIStrials,[]);
                end
            end       
        end

        %Plotting Results
        xLabel = sprintf('%s Multiplier', covType);
        if useSim
            figsBefore = findall(groot,'Type','figure');

            [RMSEmean,RMSEstd] = getCovMetric(summary,filterNames,covList,covType,'RMSE');
            plotRMSE(covList,RMSEmean,RMSEstd,filterNames,xLabel);

            [RMSImean,RMSIstd] = getCovMetric(summary,filterNames,covList,covType,'RMSI');
            plotRMSI(covList,RMSImean,RMSIstd,filterNames,'Sim',xLabel);

            [NISmean,NISstd] = getCovMetric(summary,filterNames,covList,covType,'NIS');
            plotNIS(covList,NISmean,NISstd,filterNames,'Sim',xLabel);

            [NEESmean,NEESstd] = getCovMetric(summary,filterNames,covList,covType,'NEES');
            plotNEES(covList,NEESmean,NEESstd,filterNames,xLabel,false);

            [runtimeMean,runtimeStd] = getCovRuntime(runtime,filterNames,covList,covType);          
            plotRuntime(covList,runtimeMean,runtimeStd,filterNames,'Sim',xLabel);

            simFigures = setdiff(findall(groot,'Type','figure'),figsBefore);
        end

        if useMeas
            figsBefore = findall(groot,'Type','figure');

            [RMSImean,RMSIstd] = getMeasCovMetric(summary,filterNames,covList,covType,'RMSI');
            plotRMSI(covList,RMSImean,RMSIstd,filterNames,'Sim',xLabel);

            [NISmean,NISstd] = getMeasCovMetric(summary,filterNames,covList,covType,'NIS');
            plotNIS(covList,NISmean,NISstd,filterNames,'Sim',xLabel);

            [runtimeMean,runtimeStd] = getMeasCovRuntime(runtime,filterNames,covList,covType);            
            plotRuntime(covList,runtimeMean,runtimeStd,filterNames,'Sim',xLabel);

            measFigures = setdiff(findall(groot,'Type','figure'),figsBefore);
        end
    case 'Noise'
        %Metrics Calculations
        for f = 1:numel(filterNames)
            filterName = filterNames{f};
        
            for n = 1:numel(noiseStdList)
                noiseName = sprintf('noise_%d',n);
        
                RMSEtrials = NaN(estStates,nTrials);
                RMSItrials = NaN(measStates,nTrials);
                NIStrials = NaN(1,nTrials);
                NEEStrials = NaN(1,nTrials);
        
                for trial = 1:nTrials
                    trialName = sprintf('trial_%d',trial);
                    resultData = results.Sim.(filterName).(noiseName).(trialName);
                    metrics = calcMetrics(resultData,simData.xTrue);
        
                    RMSEtrials(:,trial) = metrics.RMSE;
                    RMSItrials(:,trial) = metrics.RMSI;
                    NIStrials(trial) = metrics.meanNIS;
                    NEEStrials(trial) = metrics.meanNEES;
                end
        
                summary.Sim.(filterName).(noiseName) = summarizeMetrics(...
                        RMSEtrials,RMSItrials,NIStrials,NEEStrials);
            end
        end

        %Plot Results
        figsBefore = findall(groot,'Type','figure');

        xLabel = 'Measurement Noise Standard Deviation (rad)';

        [RMSEmean,RMSEstd] = getNoiseMetric(summary,filterNames,noiseStdList,'RMSE');
        plotRMSE(noiseStdList,RMSEmean,RMSEstd,filterNames,xLabel);

        [RMSImean,RMSIstd] = getNoiseMetric(summary,filterNames,noiseStdList,'RMSI');
        plotRMSI(noiseStdList,RMSImean,RMSIstd,filterNames,'Sim',xLabel);

        [NISmean,NISstd] = getNoiseMetric(summary,filterNames,noiseStdList,'NIS');
        plotNIS(noiseStdList,NISmean,NISstd,filterNames,'Sim',xLabel);

        [NEESmean,NEESstd] = getNoiseMetric(summary,filterNames,noiseStdList,'NEES');
        plotNEES(noiseStdList,NEESmean,NEESstd,filterNames,xLabel,false);

        [runtimeMean,runtimeStd] = getNoiseRuntime(runtime,filterNames,noiseStdList);        
        plotRuntime(noiseStdList,runtimeMean,runtimeStd,filterNames,'Sim',xLabel);

        simFigures = setdiff(findall(groot,'Type','figure'),figsBefore);
end

if saveFigures
    folderName = sprintf('%s_%s',caseType,datestr(now,'yyyy-mm-dd_HH-MM-SS'));

    figFolder = fullfile(filePath,'Figures',folderName);

    if ~exist(figFolder,'dir')
        mkdir(figFolder);
    end

    if useSim
        saveAnalysisFigures(simFigures,figFolder,caseType,'Sim');
    end

    if useMeas
        saveAnalysisFigures(measFigures,figFolder,caseType,'Meas');
    end
end

%Local Functions For Metrics Calculations
function metrics = calcMetrics(resultData, xTrue)
    %Sim/Meas Metrics
    metrics.RMSI = sqrt(mean(resultData.innov.^2,2,'omitnan'));
    metrics.meanNIS = mean(resultData.NIS,'omitnan');

    %Simulation-Only Metrics
    if ~isempty(xTrue)
        err = resultData.x - xTrue;
        metrics.RMSE = sqrt(mean(err.^2,2));
        metrics.meanNEES = mean(resultData.NEES,'omitnan');
    end
end

function stats = summarizeMetrics(RMSEtrials,RMSItrials,NIStrials,NEEStrials)
    if ~isempty(RMSEtrials)
        stats.RMSEmean = mean(RMSEtrials,2);
        stats.RMSEstd = std(RMSEtrials,0,2);
    end

    stats.RMSImean = mean(RMSItrials,2);
    stats.RMSIstd = std(RMSItrials,0,2);

    stats.NISmean = mean(NIStrials);
    stats.NISstd = std(NIStrials);

    if ~isempty(NEEStrials)
        stats.NEESmean = mean(NEEStrials);
        stats.NEESstd = std(NEEStrials);
    end
end

function [metricMean,metricStd] = getSimMetric(summary,filterNames,modNList,metricName)
    meanName = [metricName 'mean'];
    stdName = [metricName 'std'];

    modNName = sprintf('modN_%d',modNList(1));
    nStates = numel(summary.Sim.(filterNames{1}).(modNName).(meanName));

    metricMean = NaN(nStates,numel(modNList),numel(filterNames));
    metricStd = NaN(nStates,numel(modNList),numel(filterNames));

    for f = 1:numel(filterNames)
        filterName = filterNames{f};

        for m = 1:numel(modNList)
            modNName = sprintf('modN_%d',modNList(m));

            metricMean(:,m,f) = summary.Sim.(filterName).(modNName).(meanName);
            metricStd(:,m,f) = summary.Sim.(filterName).(modNName).(stdName);
        end
    end
end

function [metricMean,metricStd] = getMeasMetric(summary,filterNames,metricName)
    meanName = [metricName 'mean'];
    stdName  = [metricName 'std'];

    filterName = filterNames{1};
    nStates = numel(summary.Meas.(filterName).(meanName));

    metricMean = NaN(nStates, numel(filterNames));
    metricStd  = NaN(nStates, numel(filterNames));

    for f = 1:numel(filterNames)
        filterName = filterNames{f};

        metricMean(:,f) = summary.Meas.(filterName).(meanName);
        metricStd(:,f) = summary.Meas.(filterName).(stdName);
    end
end

function [metricMean,metricStd] = getEnsMetric(dataSummary, neList, metricName)

    meanName = [metricName 'mean'];
    stdName = [metricName 'std'];

    nStates = numel(dataSummary.EnKF.ne_5.(meanName));

    metricMean = NaN(nStates,numel(neList));
    metricStd = NaN(nStates,numel(neList));

    for n = 1:numel(neList)
        neName = sprintf('ne_%d',neList(n));

        metricMean(:,n) = dataSummary.EnKF.(neName).(meanName);
        metricStd(:,n) = dataSummary.EnKF.(neName).(stdName);
    end
end

function [metricMean,metricStd] = getCovMetric(summary,filterNames,covList,covType,metricName)
    meanName = [metricName 'mean'];
    stdName = [metricName 'std'];

    covName = sprintf('%s_%d', covType, 1);

    nStates = numel(summary.Sim.(filterNames{1}).(covName).(meanName));

    metricMean = NaN(nStates,numel(covList),numel(filterNames));
    metricStd = NaN(nStates,numel(covList),numel(filterNames));

    for f = 1:numel(filterNames)
        filterName = filterNames{f};

        for c = 1:numel(covList)
            covName = sprintf('%s_%d', covType, c);

            metricMean(:,c,f) = summary.Sim.(filterName).(covName).(meanName);
            metricStd(:,c,f) = summary.Sim.(filterName).(covName).(stdName);
        end
    end
end

function [metricMean,metricStd] = getMeasCovMetric(summary,filterNames,covList,covType,metricName)
    meanName = [metricName 'mean'];
    stdName = [metricName 'std'];

    covName = sprintf('%s_%d',covType,1);

    nStates = numel(summary.Meas.(filterNames{1}).(covName).(meanName));

    metricMean = NaN(nStates,numel(covList),numel(filterNames));
    metricStd  = NaN(nStates,numel(covList),numel(filterNames));

    for f = 1:numel(filterNames)
        filterName = filterNames{f};

        for c = 1:numel(covList)
            covName = sprintf('%s_%d',covType,c);

            metricMean(:,c,f) = summary.Meas.(filterName).(covName).(meanName);
            metricStd(:,c,f) = summary.Meas.(filterName).(covName).(stdName);
        end
    end
end

function [metricMean,metricStd] = getNoiseMetric(summary,filterNames,noiseStdList,metricName)

    meanName = [metricName 'mean'];
    stdName = [metricName 'std'];

    nStates = numel(summary.Sim.(filterNames{1}).noise_1.(meanName));

    metricMean = NaN(nStates,numel(noiseStdList),numel(filterNames));
    metricStd = NaN(nStates,numel(noiseStdList),numel(filterNames));

    for f = 1:numel(filterNames)
        filterName = filterNames{f};

        for n = 1:numel(noiseStdList)
            noiseName = sprintf('noise_%d',n);

            metricMean(:,n,f) = summary.Sim.(filterName).(noiseName).(meanName);
            metricStd(:,n,f) = summary.Sim.(filterName).(noiseName).(stdName);
        end
    end
end

function [runtimeMean,runtimeStd] = getSimRuntime(runtime,filterNames,modNList)
    runtimeMean = NaN(numel(modNList),numel(filterNames));
    runtimeStd = NaN(numel(modNList),numel(filterNames));

    for f = 1:numel(filterNames)
        filterName = filterNames{f};

        for m = 1:numel(modNList)
            modNName = sprintf('modN_%d',modNList(m));

            times = runtime.Sim.(filterName).(modNName).times;
            runtimeMean(m,f) = mean(times);
            runtimeStd(m,f) = std(times);
        end
    end
end

function [runtimeMean,runtimeStd] = getMeasRuntime(runtime,filterNames)
    runtimeMean = NaN(1,numel(filterNames));
    runtimeStd = NaN(1,numel(filterNames));

    for f = 1:numel(filterNames)
        filterName = filterNames{f};

        times = runtime.Meas.(filterName).times;
        runtimeMean(f) = mean(times);
        runtimeStd(f) = std(times);
    end
end

function [runtimeMean,runtimeStd] = getEnsRuntime(runtime,neList,modN)
    runtimeMean = NaN(numel(neList),1);
    runtimeStd  = NaN(numel(neList),1);

    modNName = sprintf('modN_%d',modN);

    for n = 1:numel(neList)
        neName = sprintf('ne_%d',neList(n));

        times = runtime.Sim.EnKF.(neName).(modNName).times;

        runtimeMean(n,1) = mean(times);
        runtimeStd(n,1)  = std(times);
    end
end

function [runtimeMean,runtimeStd] = getMeasEnsRuntime(runtime,neList)

    runtimeMean = NaN(numel(neList),1);
    runtimeStd = NaN(numel(neList),1);

    for n = 1:numel(neList)
        neName = sprintf('ne_%d',neList(n));

        times = runtime.Meas.EnKF.(neName).times;

        runtimeMean(n) = mean(times);
        runtimeStd(n) = std(times);
    end
end

function [runtimeMean,runtimeStd] = getCovRuntime(runtime,filterNames,covList,covType)

    runtimeMean = NaN(numel(covList),numel(filterNames));
    runtimeStd = NaN(numel(covList),numel(filterNames));

    for f = 1:numel(filterNames)
        filterName = filterNames{f};

        for c = 1:numel(covList)
            covName = sprintf('%s_%d',covType,c);

            times = runtime.Sim.(filterName).(covName).times;

            runtimeMean(c,f) = mean(times);
            runtimeStd(c,f)  = std(times);
        end
    end
end

function [runtimeMean,runtimeStd] = getMeasCovRuntime(runtime,filterNames,covList,covType)
    runtimeMean = NaN(numel(covList),numel(filterNames));
    runtimeStd = NaN(numel(covList),numel(filterNames));

    for f = 1:numel(filterNames)
        filterName = filterNames{f};

        for c = 1:numel(covList)
            covName = sprintf('%s_%d',covType,c);

            times = runtime.Meas.(filterName).(covName).times;

            runtimeMean(c,f) = mean(times);
            runtimeStd(c,f)  = std(times);
        end
    end
end

function [runtimeMean,runtimeStd] = getNoiseRuntime(runtime,filterNames,noiseStdList)

    runtimeMean = NaN(numel(noiseStdList),numel(filterNames));
    runtimeStd = NaN(numel(noiseStdList),numel(filterNames));

    for f = 1:numel(filterNames)
        filterName = filterNames{f};

        for n = 1:numel(noiseStdList)
            noiseName = sprintf('noise_%d',n);

            times = runtime.(filterName).(noiseName).times;

            runtimeMean(n,f) = mean(times);
            runtimeStd(n,f) = std(times);
        end
    end
end

function plotRMSE(xValues,RMSEmean,RMSEstd,filterNames,xLabel)
    stateNames = {...
        'Primary Bar Angle',...
        'Secondary Bar Angle',...
        'Primary Bar Angular Velocity',...
        'Secondary Bar Angular Velocity'};
    yLabels = {...
        'RMSE (rad)',...
        'RMSE (rad)',...
        'RMSE (rad/s)',...
        'RMSE (rad/s)'};
    for s = 1:4
        figure
        hold on

        for f = 1:numel(filterNames)
            errorbar(xValues,RMSEmean(s,:,f),RMSEstd(s,:,f),...
                '-o','DisplayName',filterNames{f})
        end

        xlabel(xLabel)
        ylabel(yLabels{s})
        title([stateNames{s} ' RMSE'])
        xticks(xValues)
        legend('Location','best')
        grid on
    end
end

function plotRMSI(xValues,RMSImean,RMSIstd,filterNames,dataType,xLabel)
    stateNames = {...
        'Primary Bar Angle',...
        'Secondary Bar Angle'};

    for s = 1:2
        figure
        hold on

        if strcmp(dataType,'Sim')
            for f = 1:numel(filterNames)
                errorbar(xValues,RMSImean(s,:,f),RMSIstd(s,:,f),...
                    '-o','DisplayName',filterNames{f})
            end
    
            xlabel(xLabel)
            xticks(xValues)
            legend('Location','best')
        elseif strcmp(dataType, 'Meas')
            x = 1:numel(filterNames);

            bar(x,RMSImean(s,:))
            hold on
        
            errorbar(x,RMSImean(s,:),RMSIstd(s,:),'k.','LineStyle','none')
        
            xlabel('Filter')
            xticks(x)
            xticklabels(filterNames)
        end

        ylabel('RMSI (rad)')
        title([stateNames{s} ' RMSI'])
        grid on
    end
end

function plotNIS(xValues, NISmean, NISstd, filterNames,dataType,xLabel)
    figure
    hold on

    if strcmp(dataType,'Sim')
        for f = 1:numel(filterNames)
            errorbar(xValues,NISmean(1,:,f),NISstd(1,:,f), ...
                '-o','DisplayName',filterNames{f})
        end

        xlabel(xLabel)
        xticks(xValues)
        legend('Location','best')
    elseif strcmp(dataType, 'Meas')   
        x = 1:numel(filterNames);
    
        bar(x,NISmean)
        hold on;
    
        errorbar(x,NISmean,NISstd,'k.','LineStyle','none');
    
        xlabel('Filter');
        xticks(x);
        xticklabels(filterNames);
    end

    yline(2,'--','Expected NIS','HandleVisibility','off')

    ylabel('Mean NIS')
    title('Mean NIS')
    grid on
end

function plotNEES(xValues,NEESmean,NEESstd,filterNames,xLabel,logScale)
    figure
    hold on

    for f = 1:numel(filterNames)
        errorbar(xValues,NEESmean(1,:,f),NEESstd(1,:,f), ...
            '-o','DisplayName',filterNames{f})
    end

    yline(4, '--','Expected NEES','HandleVisibility', 'off')

    xlabel(xLabel)
    ylabel('Mean NEES')
    title('Mean NEES')
    xticks(xValues)
    legend('Location','best')
    grid on

    if logScale
        set(gca,'Yscale','log')
    end
end

function plotRuntime(xValues,runtimeMean,runtimeStd,filterNames,dataType,xLabel)
    figure
    hold on

    if strcmp(dataType,'Sim')
        for f = 1:numel(filterNames)
            errorbar(xValues,runtimeMean(:,f),runtimeStd(:,f), ...
                '-o','DisplayName',filterNames{f})
        end
        
        xlabel(xLabel)
        xticks(xValues)
        legend('Location','best')
    elseif strcmp(dataType, 'Meas')
        x = 1:numel(filterNames);
    
        bar(x,runtimeMean)
        hold on
    
        errorbar(x, runtimeMean,runtimeStd,'k.','LineStyle','none')
    
        xlabel('Filter');
        xticks(x);
        xticklabels(filterNames);
    end

    ylabel('Runtime (s)')
    title('Filter Runtime')
    grid on
end

function saveAnalysisFigures(figures, figFolder, caseType, dataType)
    for k = 1:numel(figures)
        fig = figures(k);

        ax = findall(fig,'Type','axes');
        figTitle = ax(1).Title.String;

        if iscell(figTitle)
            figTitle = strjoin(figTitle,' ');
        end

        figTitle = regexprep(figTitle,'[<>:"/\\|?*]','_');

        fileName = sprintf('%s_%s_%s.fig',caseType,dataType,figTitle);

        savefig(fig,fullfile(figFolder,fileName));
    end
end
