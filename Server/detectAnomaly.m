function [results, saveState] = detectAnomaly(tbl, loadState)
% Detect Anomalies with One Class SVM

% Copyright 2021 The MathWorks, Inc.
     
    % Incremental learning model that we simultaneously predict with and
    % improve by training.
    model = loadState.svm;
    
    % State of the random number generator, for reproducibility.
    rng(loadState.rngState)

    % Copy the timestamp column, timestamp, which we don't use for 
    % anomaly calculations. We need to attach it to the results.
    % Also chop off other columns, like key. The online learning 
    % algorithm treats the table as a matrix of doubles.
    ts = tbl.Time;
    tbl = removevars(tbl, {'Key'});
      
    % Current set of messages. 
    X = tbl(:,:);

    % Detect anomalies in the just received data
    anomaly = isAnomaly(model,X);

    % Record also the anomaly score for a later plot
    scores(1:height(X),1) = score(model,X);

    % Update the model (oline learning) with newly received data
    model = increment(model,X);
    
    % Results will turn into a table with columns derived from the
    % structure fields. Structure fields must therefore be column vectors.
    results = timetable(ts,cast(anomaly,'int32'),scores,'VariableNames', ...
        {'Anomaly', 'Score'});
    
    saveState.svm = model;
    saveState.rngState = rng();
end
