function [results, saveState] = remainingMotorLife(tbl, loadState)
%Compute remaining useful life for a given motor. Input
%data must be for a single motor.
    
    % Load the information needed to transform the incoming data,
    transformData = load('rulHealthIndicatorTransformData');
    
    % Copy the timestamp column, which we don't use for RUL
    % calculations. We need to attach it to the results table.
    ts = tbl.Time;
    
    % Filter the table columns to extract the features required for RUL.
    %
    % Remove all those variables that are not features named in the
    % transformData.
    rmvars = setdiff(tbl.Properties.VariableNames, ...
        transformData.featureNames);
    tbl = removevars(tbl, rmvars);
    
    % Process data a row at a time
    hivector = [];
    elRULvector = [];
    threshold = 10;
    for k=1:height(tbl)
        data = tbl(k,:).Variables;
    
        %Normalize the data
        ndata = (data-transformData.normalizeMean)./transformData.normalizeSTD;

        %Map onto principle components
        pdata = ndata*transformData.coefPCA;

        %Combine principle components to create health indicator
        hidata = pdata*transformData.weights;
        
        % The RUL model persists between calls to this function.
        mdlL = loadState.rulModel;
        
        % Update the RUL model and predict.
        update(mdlL, hidata)
        [elRUL, lci] = predictRUL(mdlL, hidata, threshold);
        if isempty(mdlL.SlopeDetectionInstant)
            %Model has not detected any degradation trend, predicited 
            %RUL is not meaningful.
            elRUL = nan;
            lci = [nan nan];
        end
        hivector = [hivector ; hidata];            %#ok
        elRULvector = [elRULvector ; elRUL lci];   %#ok
    end    
    
    % Clamp elRUL to 4320 minutes, or 72 hours.
    elRULvector( elRULvector > 4320 ) = 4320;
    
    % NaN means no degradation, so adjust to nominal value.
    elRULvector( isnan(elRULvector) ) = 4320;
    
    % Simple case -- return results as a structure.
    rul.hivector = hivector;
    rul.elRUL = elRULvector(:,1); % Estimated remaining life
    rul.ciL = elRULvector(:,2);   % Low end of confidence interval
    rul.ciH = elRULvector(:,3);   % High end of confidence interval
    rul.timestamp = ts;           % Timestamp of result same as motor data
    
    % Return results and next iteration's state.
    results = timetable(ts,rul.hivector,rul.elRUL,rul.ciL,rul.ciH,...
        'VariableNames',{'HiVector','EstimatedRUL','LowCI', 'HighCI'});
    saveState.rulModel = mdlL;
 
end
