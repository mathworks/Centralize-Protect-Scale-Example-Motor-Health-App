function [rul, anomaly] = processMotorData(data, initState)
%processMotorData Compute remaining useful life for a given motor, and scan
%the motor data for anomalies.
%
%   [rul, anomaly] = processMotorData(data, initState) feeds DATA into
%   motor-specific machine learning models and returns the remaining useful
%   lifetime (RUL) and any anomalies detected (ANOMALY). 
%
% DATA, RUL and ANOMALY are structure arrays suitable for conversion into
% timetables. 
%
%    DATA fields:
%       variables: Names of the columns in VALUES.
%       values   : Motor data matrix. Each row a single observation.
%       timestamp: Timestamps of the observations in VALUES.
%
%    RUL fields:
%       EstimatedRUL: Estimated remaining useful life at time Time.
%       LowCI       : Lower bound of confidence interval at Time.
%       HighCI      : Upper bound of confidence interval at Time.
%       Time        : 
%
%    ANOMALY fields:
%       Anomaly: Boolean, true if anomaly occured at time Time.
%       Score  : Data's "anomaly" score. 
%       Time   : Millisecond-resolution 
%       

% Copyright 2021 The MathWorks, Inc.

    % Data came from the caller (a separate MATLAB process if this function
    % is deployed on MATLAB Production Server) as a structure. Convert to
    % timetable because that's the format required by the machine learning
    % algorithms.
    tt = array2timetable(data.values, ...
        'RowTimes', datetime(data.timestamp/1000, 'ConvertFrom', 'posixtime'), ...
        'VariableNames', data.variables);
    [groups, tid] = findgroups(tt.Key);
    rul = []; anomaly = [];
    
    % Connect to the Redis-backed 'MotorData' persistent data cache. Store
    % the machine learning models in that cache so they persist between
    % batches of data. MATLAB Production Server's stateless execution
    % architecture clears out all MATLAB state when it finished processing
    % a request. Since the models improve after every batch of data, we
    % need them to persist -- so we store them where MATLAB Production
    % Server can't clear them. :-)
    c = mps.cache.connect('MotorData','Connection','LocalRedis');
    
    % For each key (motor ID) in this batch of data, call the machine
    % learning analytics and collect the results.
    for n = 1:height(tid)
        
        % Extract the data for the Nth motor
        groupData = tt(groups == n,:);
        
        % Form the names of the model state variables in the persistent
        % cache: AnomalyModel1 and RULModel1 for motor 1, etc.
        aStateName = sprintf('AnomalyModel%d',tid(n));
        rStateName = sprintf('RULModel%d',tid(n));
        
        % If the model state doesn't exist, or the input initState is true,
        % then reset the model to its initial state.
        if isempty(c.(aStateName)) || initState
            c.(aStateName) = initAnomalyData();
        end
        
        % Detect anomalies, using the model retrieved from persistent
        % storage.
        aState = c.(aStateName);
        [a,aState] = detectAnomaly(groupData,aState);
        c.(aStateName) = aState;
        anomaly = vertcat(anomaly,a);
        
        % Repeat the state initialization process for remaining useful life
        % state -- initialize if it doesn't exist or if initState is true.
        if isempty(c.(rStateName)) || initState
            c.(rStateName) = initMotorRULData();
        end
        
        % Compute remaining useful lifetime and accumulate results.
        rState = c.(rStateName);
        [r, rState] = remainingMotorLife(groupData, rState);
        c.(rStateName) = rState;
        rul = vertcat(rul, r);

    end
    
    % The timetables of results can't be sent back over the wire from MATLAB
    % Production Server (whence this function is meant to be deployed) to
    % whatever client called processMotorData.
    %
    % Create a structure from each timetable, reducing timestamp from a
    % datetime to a POSIX numeric time value.
    
    ts = anomaly.Properties.RowTimes;
    anomaly = table2struct(anomaly);
    ts = num2cell(posixtime(ts));
    [anomaly(:).Time] = ts{:};
 
    ts = rul.Properties.RowTimes;
    rul = table2struct(rul);
    ts = num2cell(posixtime(ts));
    [rul(:).Time] = ts{:};
end
